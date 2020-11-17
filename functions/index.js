'use strict';

const functions = require('firebase-functions');
const express = require('express');
// The Firebase Admin SDK to access Cloud Firestore and Cloud Messaging
const admin = require('firebase-admin');
const https = require('https');
const axios = require('axios');
const cheerio = require('cheerio');

admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

const firestore = admin.firestore();
const fcMessaging = admin.messaging();

const agent = new https.Agent({
  host: 'oscar.gatech.edu',
  path: '/',
  rejectUnauthorized: false,
  keepAlive: true
});

const checkOpenings = async (req, res) => {
  const getSeats = async (term_in, crn_in) => {
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
  };

  if (req.get('Authorization') === undefined || req.get('Authorization') !== functions.config().envs.secret) {
    console.log('Attempted unauthorized request.');
    return res.end();
  }

  const currentTerm = (await firestore.collection("globalCourses").doc("currentTerm").get()).data().currentTerm;
  const previousResult = {};

  try {
    var snapshot = await firestore.collection("users").get();
  } catch (e) {
    console.error('Get users collection failed: ' + e);
    return res.status(404).send('Failure getting users.');
  }
  
  await Promise.all(snapshot.docs.map(async user => {
    const userTokens = user.data().tokens;
    return Promise.all(user.data().courses.map(async course => {
      if (course === undefined || !course.hasOwnProperty('name') || !course.hasOwnProperty('crn') || !course.hasOwnProperty('term')) {
        await firestore.collection("users").doc(user.id).update({
          'courses': admin.firestore.FieldValue.arrayRemove(course)
        });
        console.log(`Undefined Course for user ${user.id} has been deleted.`);
        return Promise.resolve();
      }

      const {name, term, crn} = course;

      if (term !== currentTerm) {
        await firestore.collection("users").doc(user.id).update({
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

        // Change to sendMulticast? Requires Message objects instead of strings but may be more efficient.
        try {
          var response = await fcMessaging.sendToDevice(userTokens, payload);
        } catch (e) {
          console.log(`FCM error for user ${user.id}: ${e}`);
          return Promise.resolve();
        }
        // For each message check if there was an error.
        return Promise.all(response.results.map(async (result, index) => {
          const error = result.error;
          if (error) {
            console.log('Failure sending cloud message to', userTokens[index], error);
            // Cleanup the tokens who are not registered anymore.
            if (error.code === 'messaging/invalid-registration-token' ||
                error.code === 'messaging/registration-token-not-registered') {
                await firestore.collection("users").doc(user.id).update({
                  'tokens': admin.firestore.FieldValue.arrayRemove(userTokens[index])
                });
            }
          }
        }));
      }

      return Promise.resolve();
    }));
  }));
  
  return res.status(200).send('Success: checked openings!');
};

const updateGlobalCourses = async (req, res) => {
  if (req.get('Authorization') === undefined || req.get('Authorization') !== functions.config().envs.secret) {
    console.log('Attempted unauthorized request.');
    return res.end();
  }

  const termsUrl = 'https://oscar.gatech.edu/pls/bprod/bwckschd.p_disp_dyn_sched';
  try {
    var termsResult = await axios.get(termsUrl, { httpsAgent: agent, timeout: 10000 });
  } catch (e) {
    console.error(`Erorr getting currentTerm: ${e}`);
    return res.status(404).send('Failure getting currentTerm.');
  }
  const $terms = cheerio.load(termsResult.data);

  const terms = $terms('table.dataentrytable select option').toArray();
  var currentTerm;
  for (let i = 0; i < terms.length; ++i) {
    let termId = terms[i].attribs.value.slice(-2);
    if (termId === '02' || termId === '05' || termId === '08') {
      currentTerm = parseInt(terms[i].attribs.value);
      break;
    }
  }

  const subjectsUrl = `https://oscar.gatech.edu/pls/bprod/bwckgens.p_proc_term_date?p_calling_proc=bwckschd.p_disp_dyn_sched&p_term=${currentTerm}`;
  try {
    var subjectsResult = await axios.get(subjectsUrl, { httpsAgent: agent, timeout: 10000 });
  } catch (e) {
    console.error(`Erorr getting subjects: ${e}`);
    return res.status(404).send('Failure getting subjects.');
  }
  
  const $subjects = cheerio.load(subjectsResult.data);

  const termName = $subjects('table.plaintable div.staticheaders').children()[0].prev.data.trim();
  const newDocument = {name: termName, subjects: []};

  try {
    await Promise.all($subjects('table.dataentrytable select option').toArray().map(async elem => {
      const subjectInitials = elem.attribs.value;
      const subjectFull = elem.firstChild.data;
      const sectionsUrl = `https://oscar.gatech.edu/pls/bprod/bwckschd.p_get_crse_unsec?term_in=${currentTerm}&sel_subj=dummy&sel_day=dummy&sel_schd=dummy&sel_insm=dummy&sel_camp=dummy&sel_levl=dummy&sel_sess=dummy&sel_instr=dummy&sel_ptrm=dummy&sel_attr=dummy&sel_subj=${subjectInitials}&sel_crse=&sel_title=&sel_schd=%25&sel_from_cred=&sel_to_cred=&sel_camp=%25&sel_ptrm=%25&sel_instr=%25&sel_attr=%25&begin_hh=0&begin_mi=0&begin_ap=a&end_hh=0&end_mi=0&end_ap=a`;
      const sectionsResult = await axios.get(sectionsUrl, { httpsAgent: agent, timeout: 30000 });
      const $sections = cheerio.load(sectionsResult.data);

      const courses = {};
      $sections('table.datadisplaytable th.ddtitle').each((ind, elem) => {
        const titleArray = elem.firstChild.firstChild.data.split(' - ');
        
        const courseName = titleArray.slice(0, -3).join(' - ');
        const crn = parseInt(titleArray[titleArray.length - 3]);
        const courseNumber = parseInt(titleArray[titleArray.length - 2].split(' ')[1]);
        const sectionLetter = titleArray[titleArray.length - 1];
        
        if (!(courseNumber in courses)) {
          courses[courseNumber] = {name: courseName, number: courseNumber, sections: []};
        }
        courses[courseNumber].sections.push({crn: crn, letter: sectionLetter});
      });

      newDocument.subjects.push({nameInitials: subjectInitials, nameFull: subjectFull, courses: Object.values(courses)});
      return Promise.resolve();
    }));
  } catch (e) {
    console.error(`Error getting sections: ${e}`);
    return res.status(404).send('Failure getting sections.');
  }

  await firestore.collection("globalCourses").doc(currentTerm.toString()).set(newDocument, {
    merge: true
  });

  return res.status(200).send('Success: updated global courses!');
};

exports.check_openings = functions.https.onRequest(checkOpenings);
exports.update_global_courses = functions.https.onRequest(updateGlobalCourses);
