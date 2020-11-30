import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gt_scheduling_app/add_courses.dart';

import 'course_info.dart';

class HomePage extends StatefulWidget {
  final String uid;

  HomePage({Key key, this.uid}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final firestoreInstance = Firestore.instance;
  final FirebaseMessaging fcMessaging = FirebaseMessaging();

  StreamSubscription<String> tokenListener;
  final Map<String, Map<String, List<CourseInfo>>> _globalCoursesMap = Map();
  Set<CourseInfo> _selectedCourses = Set();

  static Future<dynamic> backgroundMessageHandler(
      Map<String, dynamic> message) async {
    // print("onbackgroundmessage: $message");
    return Future<void>.value();
  }

  void _saveMessagingToken() {
    // Get the token for this device
    tokenListener = fcMessaging.onTokenRefresh.listen((fcMessagingToken) async {
      final sharedPrefs = await SharedPreferences.getInstance();
      final String curToken = sharedPrefs.getString('fcmToken');
      if (fcMessagingToken != curToken) {
        // Save it to Firestore
        if (fcMessagingToken != null) {
          await firestoreInstance
              .collection("users")
              .document(widget.uid)
              .updateData({
            "tokens": FieldValue.arrayUnion([fcMessagingToken])
          });
          // print('Saved token: $fcMessagingToken');
        } else {
          // print('Could not retrieve FCM token.');
        }
        await sharedPrefs.setString('fcmToken', fcMessagingToken);
      }
    });
  }

  @override
  void initState() {
    super.initState();

    if (Platform.isIOS) {
      fcMessaging.onIosSettingsRegistered.listen((data) {
        // print("IOS settings registered: $data");
        _saveMessagingToken();
      });
      fcMessaging.requestNotificationPermissions(IosNotificationSettings());
    } else {
      _saveMessagingToken();
    }

    fcMessaging.configure(
        onMessage: (Map<String, dynamic> message) async {
          // print("onMessage: $message");

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              content: Container(
                height: 50.0,
                child: ListTile(
                  title: Text(message['notification']['title']),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 5.0),
                    child: Text(message['notification']['body']),
                  ),
                ),
              ),
              actions: <Widget>[
                FlatButton(
                  color: Theme.of(context).accentColor,
                  child: Text('Ok', style: TextStyle(color: Colors.black)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
          return;
        },
        onLaunch: (Map<String, dynamic> message) async {
          // print("onLaunch: $message");
          return;
        },
        onResume: (Map<String, dynamic> message) async {
          // print("onResume: $message");
          return;
        },
        onBackgroundMessage: backgroundMessageHandler);

    populateGlobalCourses();
    populateSelectedCourses();
  }

  Future<void> removeSelectedCourses(Iterable<CourseInfo> remCourses) async {
    if (remCourses.isNotEmpty) {
      await firestoreInstance
          .collection("users")
          .document(widget.uid)
          .updateData({
        "courses": FieldValue.arrayRemove(remCourses
            .map((CourseInfo course) => course.toFirestoreObject())
            .toList())
      });
      setState(() {
        remCourses.forEach((remCourse) {
          _selectedCourses.remove(remCourse);
        });
      });
    }
  }

  Future<void> addSelectedCourses(Iterable<CourseInfo> addCourses) async {
    Set<CourseInfo> newSelected = _selectedCourses.union(addCourses.toSet());
    if (newSelected.length > _selectedCourses.length &&
        newSelected.length < 16) {
      await firestoreInstance
          .collection("users")
          .document(widget.uid)
          .updateData({
        "courses": FieldValue.arrayUnion(addCourses.map((CourseInfo course) {
          return course.toFirestoreObject();
        }).toList())
      });
      setState(() {
        _selectedCourses = newSelected;
      });
    }
  }

  Future<void> populateSelectedCourses() async {
    DocumentSnapshot result =
        await firestoreInstance.collection("users").document(widget.uid).get();
    List courses = result.data['courses'];
    setState(() {
      courses.forEach(
          (course) => _selectedCourses.add(CourseInfo.fromFirestore(course)));
    });
  }

  Future<void> populateGlobalCourses() async {
    DocumentSnapshot termIDSnapshot = await firestoreInstance
        .collection("globalCourses")
        .document("currentTerm")
        .get();
    int termID = termIDSnapshot.data["currentTerm"].toInt();

    DocumentSnapshot globalCoursesSnapshot = await firestoreInstance
        .collection("globalCourses")
        .document(termID.toString())
        .get();

    globalCoursesSnapshot.data['subjects'].forEach((subject) {
      final String subjectNameInitials = subject['nameInitials'];
      _globalCoursesMap[subjectNameInitials] = Map<String, List<CourseInfo>>();
      subject['courses'].forEach((course) {
        final String courseNumber = course['number'].toString();
        _globalCoursesMap[subjectNameInitials][courseNumber] =
            List<CourseInfo>();
        course['sections'].forEach((section) {
          _globalCoursesMap[subjectNameInitials][courseNumber].add(CourseInfo(
              term: termID,
              crn: section['crn'],
              name:
                  "$subjectNameInitials $courseNumber - ${section['letter']}"));
        });
      });
    });
  }

  void _goToAddCourses() async {
    final List<Set<CourseInfo>> updatedSelected = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) => AddCoursesPage(
                globalCoursesMap: _globalCoursesMap,
                selected: Set.from(_selectedCourses))));

    // After user has updated classes on add_courses, get updated info here:
    await removeSelectedCourses(updatedSelected[0]);
    await addSelectedCourses(updatedSelected[1]);
  }

  Widget _getSelectedCoursesListView() {
    final tiles = _selectedCourses.map(
      (CourseInfo info) {
        return ListTile(
          title: Text(
            info.name,
          ),
          trailing: IconButton(
            icon: Icon(
              Icons.favorite,
              color: Colors.red,
            ),
            onPressed: () {
              removeSelectedCourses([info]);
            },
          ),
        );
      },
    );

    final divided = ListTile.divideTiles(
      context: context,
      tiles: tiles,
    ).toList();

    return ListView(
      children: divided,
      shrinkWrap: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Courses'),
        actions: <Widget>[
          FlatButton(
            child: Text("Log Out"),
            textColor: Colors.black,
            onPressed: () async {
              await tokenListener.cancel();
              await fcMessaging.deleteInstanceID();
              FirebaseAuth.instance
                  .signOut()
                  .then((result) =>
                      Navigator.pushReplacementNamed(context, "/login"))
                  .catchError((err) {
                // print(err);
              });
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          children: [
            Expanded(
              child: _getSelectedCoursesListView(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToAddCourses,
        tooltip: 'Add',
        child: Icon(Icons.add),
      ),
    );
  }
}
