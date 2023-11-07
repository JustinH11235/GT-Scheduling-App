'use strict';

// Library Required for Firebase Cloud Functions
const functions = require('firebase-functions');
// The Firebase Admin SDK used to access Cloud Firestore and Cloud Messaging
const admin = require('firebase-admin');
// HTTP Request Libraries
const https = require('https');
const axios = require('axios');
// Web Scraping Library
const cheerio = require('cheerio');

admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

const firestore = admin.firestore();
const fcMessaging = admin.messaging();

// Initialize HTTPS Agent to only have access to OSCAR
const agent = new https.Agent({
  host: 'oscar.gatech.edu',
  path: '/',
  rejectUnauthorized: false
});

/**
 * Iterates over all users in the Firestore users collection and sends a push notification
 * for every course that has either open seats or open waitlist spots
 * 
 * @param {Object} req "ExpressJS-style" HTTP Request
 * @param {Object} res "ExpressJS-style" HTTP Response
 */
const checkOpenings = async (req, res) => {
  if (req.get('Authorization') === undefined || req.get('Authorization') !== functions.config().envs.secret) {
    console.log('Attempted unauthorized request.');
    return res.end();
  }

  // Get the current term from Firestore
  try {
    var currentTerm = (await firestore.collection("globalCourses").doc("currentTerm").get()).data().currentTerm;
  } catch (e) {
    console.error(`Error getting current term: ${e}`);
    return res.status(404).send('Failure getting current term.');
  }

  // Stores mappings of previously processed CRNs to seat info objects
  const previousResult = {};
  // Stores tokens that have already been removed and should not be removed again
  const badTokens = new Set();

  /**
   * Queries OSCAR for the given course section and returns an object containing
   * the current seat data of the section
   * 
   * @param {Number} term_in the term of the given CRN
   * @param {Number} crn_in the five-digit CRN of the desired course section
   * @returns {Object} data regarding the current normal and waitlist seats for the given section
   */
  async function getSeats(term_in, crn_in) {
    const url = `https://oscar.gatech.edu/pls/bprod/bwckschd.p_disp_detail_sched?term_in=${term_in}&crn_in=${crn_in}`;
    const result = await axios.get(url, { httpsAgent: agent });
    const $ = cheerio.load(result.data);
    const seatData = $('table.datadisplaytable table.datadisplaytable td.dddefault');

    const parseTableData = tableData => parseInt(tableData.firstChild.data);

    return {
      seats: {
        capacity: parseTableData(seatData[0]),
        taken: parseTableData(seatData[1]),
        open: parseTableData(seatData[2])
      }, waitlist: {
        capacity: parseTableData(seatData[3]),
        taken: parseTableData(seatData[4]),
        open: parseTableData(seatData[5])
      }
    };
  }

  /**
   * Calls getSeats to get the section's seat data and sends a push notification
   * to all of the user's tokens if there is an opening
   * 
   * @param {[Array, Number, Array]} param user and course information to be processed
   * @param {Object} param.course course information to be processed
   * @param {Number} param.id uid of the user
   * @param {Array} param.tokens cloud messaging tokens of the user
   * @returns {Promise} resolved promise when complete
   */
  async function processCourse([course, id, tokens]) {
    if (course === undefined || !course.hasOwnProperty('name') || !course.hasOwnProperty('crn') || !course.hasOwnProperty('term')) {
      firestore.collection("users").doc(id).update({
        'courses': admin.firestore.FieldValue.arrayRemove(course)
      });
      console.log(`Undefined Course for user ${id} has been deleted.`);
      return Promise.resolve();
    }

    const { name, term, crn } = course;

    if (term !== currentTerm) {
      firestore.collection("users").doc(id).update({
        'courses': admin.firestore.FieldValue.arrayRemove(course)
      });
      console.log(`Course ${crn} with term ${term} does not match current term ${currentTerm} and has been deleted.`);
      return Promise.resolve();
    }

    var seatInfo;

    if (crn in previousResult) {
      seatInfo = previousResult[crn];
    } else {
      try {
        var openings = await getSeats(term, crn);
      } catch (e) {
        console.log('getSeats: ' + e);
        return Promise.resolve();
      }
      previousResult[crn] = openings;
      seatInfo = openings;
    }

    if (seatInfo.seats.open || seatInfo.waitlist.open) {
      var payload = {
        notification: seatInfo.seats.open ? {
          title: 'Course Opening',
          body: `${name} is OPEN with ${seatInfo.seats.open} seats!`,
          clickAction: 'FLUTTER_NOTIFICATION_CLICK'
        } : {
          title: 'Course Opening (Waitlist)',
          body: `${name} waitlist is OPEN with ${seatInfo.waitlist.open} spots!`,
          clickAction: 'FLUTTER_NOTIFICATION_CLICK'
        }
      };

      try {
        var response = await fcMessaging.sendToDevice(tokens, payload);
      } catch (e) {
        console.log(`FCM error for user ${id}: ${e}`);
        return Promise.resolve();
      }
      // For each message check if there was an error.
      return Promise.all(response.results.map(async (result, index) => {
        const error = result.error;
        if (error) {
          // Cleanup the tokens who are not registered anymore.
          if ((error.code === 'messaging/invalid-registration-token' ||
            error.code === 'messaging/registration-token-not-registered') &&
            !badTokens.has(tokens[index])) {
            badTokens.add(tokens[index]);
            firestore.collection("users").doc(id).update({
              'tokens': admin.firestore.FieldValue.arrayRemove(tokens[index])
            });
          }
          console.log('Failure sending cloud message to:', id, 'with tokenID:', tokens[index], error);
        }
        return Promise.resolve();
      }));
    }

    return Promise.resolve();
  }

  /**
   * Asyncronously processes the group of 50 courses by calling processCourse
   * on each using map
   * 
   * @param {Array} chunk group of at most 50 course arrays
   * @returns {Promise} resolved promise when complete
   */
  function processChunkInParallel(chunk) {
    return Promise.all(chunk.map(courseRequest => processCourse(courseRequest)));
  }

  /**
   * Processes groups of 50 courses one at a time by calling
   * processChunkInParallel
   * 
   * @param {Array} chunks groups of 50 courses to be processed
   * @param {Array} parentResult array of promises used by processChunks
   * @returns {Array<Promise>} array of promises resulting from processChunkInParallel calls
   */
  function processChunksInSeries(chunks, parentResult) {
    const result = [];
    return chunks.reduce((acc, chunk, ind) => {
      acc = acc.then(async () => {
        return (processChunkInParallel(chunk).then(res => {
          parentResult.push(res);
          console.log('finished chunk ' + ind);
          return result.push(res);
        }));
      });
      return acc;
    }, Promise.resolve()).then(() => result);
  }

  /**
   * Processes courses by calling processChunksInSeries
   * 
   * @param {Array} chunks groups of 50 courses to be processed
   * @returns {Promise} array of promises resulting from processChunksInSeries
   */
  function processChunks(chunks) {
    const result = [];
    return processChunksInSeries(chunks, result).then(() => result);
  }

  try {
    try {
      var snapshot = await firestore.collection("users").get();
    } catch (e) {
      console.error('Get users collection failed: ' + e);
      return res.status(404).send('Failure getting users.');
    }

    // Adds elibible courses to a requestChunks array in groups of 50
    const requestChunks = [];
    var count = 0;
    for (const user of snapshot.docs) {
      const tokens = user.data().tokens;
      // Skip if user does not have any device messaging tokens
      if (tokens === undefined || tokens.length === 0) {
        continue;
      }
      for (const course of user.data().courses) {
        let index = (count / 50) | 0;
        if (index >= requestChunks.length) {
          requestChunks.push([[course, user.id, tokens]]);
        } else {
          requestChunks[index].push([course, user.id, tokens]);
        }
        ++count;
      }
    }

    await processChunks(requestChunks);

    return res.status(200).send('Success: checked openings!');
  } catch (e) {
    console.error(`Global ERROR: ${e}`);
    return res.status(404).send('Failure checking openings.');
  }
};

/**
 * Iterates over every course section currently offerred in OSCAR for the current term
 * and updates the Firestore globalCourses collection with the updated courses
 * 
 * @param {Object} req "ExpressJS-style" HTTP Request
 * @param {Object} res "ExpressJS-style" HTTP Response
 */
const updateGlobalCourses = async (req, res) => {
  if (req.get('Authorization') === undefined || req.get('Authorization') !== functions.config().envs.secret) {
    console.log('Attempted unauthorized request.');
    return res.end();
  }

  // Get most recent term from OSCAR and store in currentTerm variable
  try {
    const termsUrl = 'https://oscar.gatech.edu/pls/bprod/bwckschd.p_disp_dyn_sched';
    try {
      var termsResult = await axios.get(termsUrl, { httpsAgent: agent });
    } catch (e) {
      console.error(`Erorr getting currentTerm: ${e}`);
      return res.status(404).send('Failure getting currentTerm.');
    }
    const $terms = cheerio.load(termsResult.data);

    const terms = $terms('table.dataentrytable select option').toArray();
    var currentTerm;
    for (let i = 0; i < terms.length; ++i) {
      let termId = terms[i].attribs.value.slice(-2);
      // '02': Spring, '05': Fall, '08': Summer
      if (termId === '02' || termId === '05' || termId === '08') {
        currentTerm = parseInt(terms[i].attribs.value);
        break;
      }
    }

    // Get all course subjects for the current term from OSCAR
    const subjectsUrl = `https://oscar.gatech.edu/pls/bprod/bwckgens.p_proc_term_date?p_calling_proc=bwckschd.p_disp_dyn_sched&p_term=${currentTerm}`;
    try {
      var subjectsResult = await axios.get(subjectsUrl, { httpsAgent: agent });
    } catch (e) {
      console.error(`Erorr getting subjects: ${e}`);
      return res.status(404).send('Failure getting subjects.');
    }

    const $subjects = cheerio.load(subjectsResult.data);

    const termName = $subjects('table.plaintable div.staticheaders').children()[0].prev.data.trim();
    const newDocument = { name: termName, subjects: [] };

    try {
      // For each subject, get every section and add its data to newDocument
      await Promise.all($subjects('table.dataentrytable select option').get().map(async elem => {
        var sectionsUrl = null;
        try {
          const subjectInitials = elem.attribs.value;
          const subjectFull = elem.firstChild.data;
          sectionsUrl = `https://oscar.gatech.edu/pls/bprod/bwckschd.p_get_crse_unsec?term_in=${currentTerm}&sel_subj=dummy&sel_day=dummy&sel_schd=dummy&sel_insm=dummy&sel_camp=dummy&sel_levl=dummy&sel_sess=dummy&sel_instr=dummy&sel_ptrm=dummy&sel_attr=dummy&sel_subj=${subjectInitials}&sel_crse=&sel_title=&sel_schd=%25&sel_from_cred=&sel_to_cred=&sel_camp=%25&sel_ptrm=%25&sel_instr=%25&sel_attr=%25&begin_hh=0&begin_mi=0&begin_ap=a&end_hh=0&end_mi=0&end_ap=a`;
          const sectionsResult = await axios.get(sectionsUrl, { httpsAgent: agent });
          const $sections = cheerio.load(sectionsResult.data);

          const courses = {};
          // Iterate over every section and update courses object with its data
          $sections('table.datadisplaytable th.ddtitle').each((ind, elem) => {
            const titleArray = elem.firstChild.firstChild.data.split(' - ');

            const courseName = titleArray.slice(0, -3).join(' - ');
            const crn = parseInt(titleArray[titleArray.length - 3]);
            const courseNumber = parseInt(titleArray[titleArray.length - 2].split(' ')[1]);
            const sectionLetter = titleArray[titleArray.length - 1];

            if (!(courseNumber in courses)) {
              courses[courseNumber] = { name: courseName, number: courseNumber, sections: [] };
            }
            courses[courseNumber].sections.push({ crn: crn, letter: sectionLetter });
          });

          newDocument.subjects.push({ nameInitials: subjectInitials, nameFull: subjectFull, courses: Object.values(courses) });
          return Promise.resolve();
        } catch (e) {
          console.error(`Error getting section ${sectionsUrl}: ${e}`);
          return Promise.resolve(); // ignore error, just log
        }
      }));
    } catch (e) {
      console.error(`Error getting sections: ${e}`);
      return res.status(404).send('Failure getting sections.');
    }

    // Updates Firestore globalCourses collection with new courses
    await firestore.collection("globalCourses").doc(currentTerm.toString()).set(newDocument, {
      merge: true
    });

    // Updates Firestore current term to be new current term
    await firestore.collection("globalCourses").doc("currentTerm").update({ 'currentTerm': currentTerm });

    return res.status(200).send('Success: updated global courses!');
  } catch (e) {
    console.error(`Global ERROR: ${e}`);
    return res.status(404).send('Failure updating global courses.');
  }
};

exports.check_openings = functions.https.onRequest(checkOpenings);
exports.update_global_courses = functions.https.onRequest(updateGlobalCourses);
