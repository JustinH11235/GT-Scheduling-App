import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

  Set<CourseInfo> _selectedCourses = Set();

  // static Future<dynamic> backgroundMessageHandler(
  //     Map<String, dynamic> message) async {
  //   print("onbackgroundmessage: $message");
  //   return Future<void>.value();
  // }

  @override
  void initState() {
    super.initState();
    // Somewhere we need to add current token to firestore on startup
    fcMessaging
        .getToken()
        .then((value) => print("This is your fcm token: " + value));

    fcMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
        print("onMessage: $message");
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
                content: ListTile(
                  title: Text(message['notification']['title']),
                  subtitle: Text(message['notification']['body']),
                ),
                actions: <Widget>[
                  FlatButton(
                    color: Colors.amber,
                    child: Text('Ok'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
        );
      },
      onLaunch: (Map<String, dynamic> message) async {
        print("onLaunch: $message");
        // TODO optional
      },
      onResume: (Map<String, dynamic> message) async {
        print("onResume: $message");
        // TODO optional
      },
    );

    populateSelectedCourses();
  }

  void removeSelectedCourses(Iterable<CourseInfo> remCourses) async {
    setState(() {
      firestoreInstance.collection("users").document(widget.uid).updateData({
        "courses": FieldValue.arrayRemove(remCourses.map((CourseInfo course) {
          return {"crn": course.crn, "name": course.name};
        }).toList())
      });
      remCourses.forEach((remCourse) {
        _selectedCourses
            .removeWhere((selectedCourse) => selectedCourse == remCourse);
      });
    });
  }

  void addSelectedCourses(Iterable<CourseInfo> addCourses) async {
    setState(() {
      firestoreInstance.collection("users").document(widget.uid).updateData({
        "courses": FieldValue.arrayUnion(addCourses.map((CourseInfo course) {
          return {"crn": course.crn, "name": course.name};
        }).toList())
      });
      addCourses.forEach((addCourse) {
        _selectedCourses.add(addCourse);
      });
    });
  }

  Future<void> populateSelectedCourses() async {
    DocumentSnapshot result =
        await firestoreInstance.collection("users").document(widget.uid).get();
    List temp = result.data['courses'];
    setState(() => temp.forEach((elem) => {
          _selectedCourses.add(CourseInfo(
              name: elem['name'], crn: elem['crn'], term: elem['term']))
        }));
  }

  void _goToAddCourses() async {
    final List<Set<CourseInfo>> updatedSelected = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) =>
                AddCoursesPage(selected: _selectedCourses)));

    // After user has updated classes on add_courses, get updated info:
    Set<CourseInfo> removed = updatedSelected[0], added = updatedSelected[1];
    removeSelectedCourses(removed);
    addSelectedCourses(added);
  }

  Widget _getSelectedCoursesListView() {
    final tiles = _selectedCourses.map(
      (CourseInfo info) {
        return ListTile(
          title: Text(
            info.name,
          ),
          trailing: Icon(
            Icons.delete,
            color: Colors.grey,
          ),
          onTap: () {
            removeSelectedCourses([info]);
          },
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
            textColor: Colors.white,
            onPressed: () {
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
