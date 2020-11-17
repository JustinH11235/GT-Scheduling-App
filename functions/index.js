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

const app = express();

const agent = new https.Agent({
  host: 'oscar.gatech.edu',
  path: '/',
  rejectUnauthorized: false
});

const currentTerm = 202102;

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

app.get('/check_openings/', async (req, res) => {
  if (req.get('Authorization') === undefined || req.get('Authorization') !== functions.config().envs.secret) {
    console.log('Attempted unauthorized request.');
    return res.end();
  }

  const previousResult = {};

  try {
    var snapshot = await firestore.collection("users").get();
  } catch (e) {
    console.log('Get users collection failed: ' + e);
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
});

app.get('/update_global_courses/', async (req, res) => {
  if (req.get('Authorization') === undefined || req.get('Authorization') !== functions.config().envs.secret) {
    console.log('Attempted unauthorized request.');
    return res.end();
  }

  const subjectsUrl = `https://oscar.gatech.edu/pls/bprod/bwckgens.p_proc_term_date?p_calling_proc=bwckschd.p_disp_dyn_sched&p_term=${currentTerm}`;
  const subjestsResult = await axios.get(subjectsUrl, { httpsAgent: agent });
  
  const $ = cheerio.load(await axios.get(subjectsUrl, { httpsAgent: agent }).data);

  const termName = $('table.plaintable div.staticheaders').children()[0].prev.data.trim();
  const subjects = $('table.dataentrytable select').children().map((ind, elem) => {
    return {
      subjectInitials: elem.attribs.value,
      subjectFull: elem.firstChild.data
    };
  }).get();
  
  const newDocument = {name: termName, subjects: []};
  
  await Promise.all(subjects.map(async ({subjectInitials, subjectFull}) => {
    const coursesUrl = `https://oscar.gatech.edu/pls/bprod/bwckschd.p_get_crse_unsec?term_in=${currentTerm}&sel_subj=dummy&sel_day=dummy&sel_schd=dummy&sel_insm=dummy&sel_camp=dummy&sel_levl=dummy&sel_sess=dummy&sel_instr=dummy&sel_ptrm=dummy&sel_attr=dummy&sel_subj=${subjectInitials}&sel_crse=&sel_title=&sel_schd=%25&sel_from_cred=&sel_to_cred=&sel_camp=%25&sel_ptrm=%25&sel_instr=%25&sel_attr=%25&begin_hh=0&begin_mi=0&begin_ap=a&end_hh=0&end_mi=0&end_ap=a`;
    const coursesResult = await axios.get(coursesUrl, { httpsAgent: agent });
  
    const $ = cheerio.load(coursesResult.data);

    const courses = {};

    $('table.datadisplaytable th.ddtitle').each((ind, elem) => {
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
  
  await firestore.collection("globalCourses").doc(currentTerm.toString()).set(newDocument, {
    merge: true
  });

  return res.status(200).send('Success: updated global courses!');
});

exports.api = functions.https.onRequest(app);
