const functions = require('firebase-functions');
const express = require('express');
// Enable cross-origin requests from cron-jobs
const cors = require('cors');
// The Firebase Admin SDK to access Cloud Firestore
const admin = require('firebase-admin');
const axios = require('axios');
const cheerio = require('cheerio');

admin.initializeApp();

const app = express();

// app.use(cors({ origin: true }));
// TODO: Replace true with cron-job origin

const getSeats = async (term_in, crn_in) => {
  const seatData = [];

  const $ = await querySection(term_in, crn_in);
  const response = $('span:contains("Seats")');
  response.first().parent().siblings().toArray().forEach((elem) => {
    seatData.push(parseInt(elem.children[0].data));
  });

  return seatData;
};

const querySection = async (term_in, crn_in) => {
  var result = await axios.get(`https://oscar.gatech.edu/pls/bprod/bwckschd.p_disp_detail_sched?term_in=${term_in}&crn_in=${crn_in}`);
  return cheerio.load(result.data);
};

app.get('/check_openings/', async (req, res) => {
  const tempTrackedClassList = [[202008, 88045]]
  tempTrackedClassList.forEach(async ([term, crn]) => {
    var seats = await getSeats(term, crn);
    console.log(seats);
    // TODO: Actually do something with the seat dat
    // (i.e. integrate push notifications and use firecloud store to get auth tokens)
  });

  res.send('Success!');
  // TODO: Error handling and respective response messages
});

exports.api = functions.https.onRequest(app);
