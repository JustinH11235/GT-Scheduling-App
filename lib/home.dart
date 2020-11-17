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

  final Map<String, Map<String, List<CourseInfo>>> _globalCoursesMap = Map();
  Set<CourseInfo> _selectedCourses = Set();

  static Future<dynamic> backgroundMessageHandler(
      Map<String, dynamic> message) async {
    print("onbackgroundmessage: $message");
    return Future<void>.value();
  }

  void _saveMessagingToken() {
    // Get the token for this device
    fcMessaging.onTokenRefresh.listen((fcMessagingToken) async {
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
          print('Saved token: $fcMessagingToken');
        } else {
          print('Could not retrieve FCM token.');
        }
        await sharedPrefs.setString('fcmToken', fcMessagingToken);
      } else {
        print('Old fcm token.');
      }
    });
  }

  @override
  void initState() {
    super.initState();
    print('home init state happened');

    if (Platform.isIOS) {
      fcMessaging.onIosSettingsRegistered.listen((data) {
        print("IOS settings registered: $data");
        _saveMessagingToken();
      });
      fcMessaging.requestNotificationPermissions(IosNotificationSettings());
    } else {
      _saveMessagingToken();
    }

    fcMessaging.configure(
        onMessage: (Map<String, dynamic> message) async {
          print("onMessage: $message");

          // Refactor to make snackbar work?
          // final snackbar = SnackBar(
          //   content: Text(message['notification']['title']),
          //   action: SnackBarAction(
          //     label: 'Go',
          //     onPressed: () => null,
          //   ),
          //   duration: Duration(seconds: 4),
          // );

          // Scaffold.of(context).showSnackBar(snackbar);
          // _scaffoldKey.currentState.showSnackBar(snackbar);

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
          print("onLaunch: $message");
          return;
        },
        onResume: (Map<String, dynamic> message) async {
          print("onResume: $message");
          return;
        },
        onBackgroundMessage: backgroundMessageHandler);

    populateGlobalCourses();
    populateSelectedCourses();
  }

  void removeSelectedCourses(Iterable<CourseInfo> remCourses) async {
    if (remCourses.isNotEmpty) {
      setState(() {
        firestoreInstance.collection("users").document(widget.uid).updateData({
          "courses": FieldValue.arrayRemove(remCourses.map((CourseInfo course) {
            return course.toFirestoreObject();
          }).toList())
        });
        remCourses.forEach((remCourse) {
          _selectedCourses
              .removeWhere((selectedCourse) => selectedCourse == remCourse);
        });
      });
    }
  }

  void addSelectedCourses(Iterable<CourseInfo> addCourses) async {
    if (addCourses.isNotEmpty) {
      setState(() {
        firestoreInstance.collection("users").document(widget.uid).updateData({
          "courses": FieldValue.arrayUnion(addCourses.map((CourseInfo course) {
            return course.toFirestoreObject();
          }).toList())
        });
        addCourses.forEach((addCourse) {
          _selectedCourses.add(addCourse);
        });
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
    removeSelectedCourses(updatedSelected[0]);
    addSelectedCourses(updatedSelected[1]);
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
            onPressed: () {
              fcMessaging.deleteInstanceID();
              FirebaseAuth.instance
                  .signOut()
                  .then((result) =>
                      Navigator.pushReplacementNamed(context, "/login"))
                  .catchError((err) => print(err));
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          children: [
            _getSelectedCoursesListView(),
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
