'use strict';

const functions = require('firebase-functions');
const express = require('express');
// Enable cross-origin requests from cron-jobs
const cors = require('cors');
// The Firebase Admin SDK to access Cloud Firestore
const admin = require('firebase-admin');
const axios = require('axios');
const cheerio = require('cheerio');

admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

const firestore = admin.firestore();
const fcMessaging = admin.messaging();

const app = express();

app.use(cors({ origin: ['http://195.201.26.157', 'http://116.203.134.67', 'http://116.203.129.16'] }));

const getSeats = async (term_in, crn_in) => {
  const $ = await querySection(term_in, crn_in);
  const response = $('span:contains("Seats")');
  const seatData = response.first().parent().siblings();

  return {
    capacity: seatData[0].children[0].data,
    taken: seatData[1].children[0].data,
    open: seatData[2].children[0].data
  };
};

const querySection = async (term_in, crn_in) => {
  const result = await axios.get(`https://oscar.gatech.edu/pls/bprod/bwckschd.p_disp_detail_sched?term_in=${term_in}&crn_in=${crn_in}`);
  return cheerio.load(result.data);
};

app.get('/check_openings/', async (req, res) => {
  if (req.get('Authorization') === undefined || req.get('Authorization') !== functions.config().envs.secret) {
    res.end();
    return;
  }

  const previousResult = {};

  try {
    var snapshot = await firestore.collection("users").get();
  } catch (e) {
    console.log('Get users collection failed: ' + e);
    res.status(404).send('Failure: ' + e.name);
  }

  snapshot.forEach(async user => {
    const userTokens = user.data().tokens;
    user.data().courses.forEach(async (course) => {
      if (course === undefined || !course.hasOwnProperty('name') || !course.hasOwnProperty('crn') || !course.hasOwnProperty('term')) {
        console.log('Undefined Course for user: ' + user.id);
        return;
      }

      const {name, term, crn} = course;
      var openSeats;

      if (crn in previousResult) {
        openSeats = previousResult[crn];
      } else {
        try {
          var seats = await getSeats(term, crn);
        } catch (e) {
          console.log('getSeats: ' + e);
          return;
        }
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

        // Change to sendMulticast? Requires Message objects instead of strings but may be more efficient.
        try {
          var response = await fcMessaging.sendToDevice(userTokens, payload);
        } catch (e) {
          console.log(`FCM error for user ${user.id}:  + ${e}`);
          return;
        }
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
          }
        });
      }
    });
  });
  
  res.status(200).send('Success: checked openings!');
});

exports.api = functions.https.onRequest(app);
