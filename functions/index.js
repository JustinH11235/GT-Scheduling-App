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

// app.use(cors({ origin: true }));
// TODO: Replace true with cron-job origin

const getSeats = async (term_in, crn_in) => {
  // const seatData = [];

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
  const snapshot = await firestore.collection("users").get();

  snapshot.forEach(async user => {
    user.data().courses.forEach(async ({name, term, crn}) => {
      console.log(term, 'term|crn', crn)
      var seats = await getSeats(term, crn);
      console.log(seats);
      // TODO: Actually do something with the seat data
      // (i.e. integrate push notifications and use firecloud store to get auth tokens)
      const payload = {
        notification: {
          title: 'You got a msg!',
          body: `${name} ${seats.open > 0 ? 'OPEN' : 'CLOSED'}`,
          click_action: 'FLUTTER_NOTIFICATION_CLICK'
        }
      };
      try {
        // Change to sendMulti-
        const response = await fcMessaging.sendToDevice(user.data().tokens[0], payload);
        console.log('sent push?')
        console.log(response)
      } catch (e) {
        console.log(e)
      }
    });
    
    
  });

  res.send('Success!');
  // TODO: Error handling and respective response messages
});

exports.api = functions.https.onRequest(app);
