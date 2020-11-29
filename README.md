# The GT Scheduling App

## Overview:

Current Functionality:
- [x] Allows users to track classes and get alerts when sections open.
- [x] Users can create accounts to save courses across devices, verify their email, and reset their password.
- [x] Receive alerts every 2 minutes for any course and section at Georgia Tech.
- [x] Get alerts for waitlist openings if there is no space in the course
- [x] Course offerings for current term updated twice daily.

Future Plans:
- [ ] Visualize schedules.
- [ ] See professor ratings and grade point averages.
- [ ] Pre-requisite checker to ensure you are allowed to take all of your planned courses

## Main Technologies Used:

* **Flutter** - Mobile App framework written in Dart used to develop cross-platform applications
* **Firebase** - BaaS (Backend as a service) developed by Google which provides the following services together with GCP (Google Cloud Platform)
  * **Cloud Firestore** - The primary database which stores both user info and an updated copy of Georgia Tech's course offerings for each term
  * **Authentication** - Uses email and password to authenticate users; includes email verification and password resetting
  * **Cloud Messaging** - Used to easily send push notifications from Firebase Cloud Functions
  * **Cloud Functions** - Composed of two functions written in Node.js that use _**Axios**_ and _**Cheerio**_ to web scrape the Georgia Tech website:
    1. Course Offerings Updater - updates current copy of course offerings every 12 hours
    2. Opening Checker - Checks for openings in tracked courses and sends push notifications to registered devices every 2 minutes
* **cron-job&#46;org** - Free cronjob scheduler used to trigger execution of Firebase Cloud Functions

## Images:

<div style="text-align: center">

  <img src="https://user-images.githubusercontent.com/61996677/100555528-285c6c80-326a-11eb-8237-75dd5a64401b.png" width="250" alt="Login Page">

  <img src="https://user-images.githubusercontent.com/61996677/100555541-3c07d300-326a-11eb-8528-7fcf951348db.png" width="250" alt="Register Page">

  <img src="https://user-images.githubusercontent.com/61996677/100555544-3f9b5a00-326a-11eb-9299-bcd46a3b8251.png" width="250" alt="Password Reset Page">

  <img src="https://user-images.githubusercontent.com/61996677/100555550-43c77780-326a-11eb-8810-f085f9d8227b.png" width="250" alt="Your Courses Page">

  <img src="https://user-images.githubusercontent.com/61996677/100555552-44f8a480-326a-11eb-953b-8cd4b7d051e9.png" width="250" alt="Add Courses Page">

  <img src="https://user-images.githubusercontent.com/61996677/100555555-488c2b80-326a-11eb-9ed1-87e9f2d6dfaf.png" width="250" alt="In-app Notifications">

  <img src="https://user-images.githubusercontent.com/61996677/100555875-6195dc00-326c-11eb-8aeb-de16fadd7eab.png" width="250" alt="Out-of-app Notifications">

</div>

## Things I'm Proud Of:

### **Course Opening Checker -**
I wanted users to be able to track as many courses as they could realistically need, which means my cloud function, which runs every two minutes, needed to be as efficient as possible.

However, after using JavaScript's sync await with promises to asyncronously process users and courses, my function began to hit rate limits. I haven't determined if this was the Georgia Tech servers or Node.js itself, but I started looking into Node.js rate limiter packages.

After searching, I decided that the added dependency wasn't worth the extra cold boot time, so I designed my own request rate limiter, which processes batches of 50 requests at a time asyncronously.

