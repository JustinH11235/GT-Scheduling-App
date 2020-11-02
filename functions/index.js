const functions = require('firebase-functions');
const express = require('express');
// Enable cross-origin requests from cron-jobs
const cors = require('cors');
// The Firebase Admin SDK to access Cloud Firestore
const admin = require('firebase-admin');
const axios = require('axios');
const cheerio = require('cheerio');

// Change in production
const serviceAccount = require('C:\\Users\\micro\\Desktop\\flutter_projects\\gt-scheduling-app-firebase-adminsdk-iikqv-5cbc97b8a9.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
  // credential: admin.credential.applicationDefault()
});

const firestore = admin.firestore();
const fcMessaging = admin.messaging();

const app = express();

app.use(cors({ origin: ['http://195.201.26.157', 'http://116.203.134.67', 'http://116.203.129.16'] }));

const getSeats = async (term_in, crn_in) => {
  const $ = await querySection(term_in, crn_in);
  const response = $('span:contains("Seats")');
  const seatData = response.first().parent().siblings();

  return {capacity: seatData[0].children[0].data, taken: seatData[1].children[0].data, open: seatData[2].children[0].data};
};

const querySection = async (term_in, crn_in) => {
  var result = await axios.get(`https://oscar.gatech.edu/pls/bprod/bwckschd.p_disp_detail_sched?term_in=${term_in}&crn_in=${crn_in}`);
  return cheerio.load(result.data);
};

app.get('/check_openings/', async (req, res) => {
  const previousResult = {};

  const snapshot = await firestore.collection("users").get();

  snapshot.forEach(async user => {
    user.data().courses.forEach(async (course) => {
      if (course == undefined || !course.hasOwnProperty('name') || !course.hasOwnProperty('crn') || !course.hasOwnProperty('term')) {
        console.log('Undefined Course for user: ' + user.id);
        return;
      }
      const {name, term, crn} = course;
      var openSeats;

      if (crn in previousResult) {
        openSeats = previousResult[crn];
      } else {
        const seats = await getSeats(term, crn);
        previousResult[crn] = seats.open;
        openSeats = seats.open;
      }

      if (openSeats > 0) {
        const payload = {
          notification: {
            title: 'Course Opening',
            body: `${name} is OPEN with ${openSeats} seats!`,
            clickAction: 'FLUTTER_NOTIFICATION_CLICK'
          }
        };

        try {
          // Change to sendMulticast? Requires Message objects instead of strings but may be more efficient.
          const userTokens = user.data().tokens;
          const response = await fcMessaging.sendToDevice(userTokens, payload);
          // For each message check if there was an error.
          response.results.forEach(async (result, index) => {
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
            } else {
              // No error sending cloud message
            }
          });
          // console.log(response)
        } catch (e) {
          console.log(e)
        }
      }
    });
    
    
  });

  res.send('Success!');
  // TODO: Error handling and respective response messages
});

exports.api = functions.https.onRequest(app);
