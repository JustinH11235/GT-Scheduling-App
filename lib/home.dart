import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gt_scheduling_app/add_courses.dart';

import 'course_info.dart';

class HomePage extends StatefulWidget {
  final String uid;

  HomePage({Key key, this.uid}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Set<CourseInfo> _selectedCourses = Set();

  @override
  void initState() {
    populateSelectedCourses();

    super.initState();
  }

  Future<void> populateSelectedCourses() async {
    DocumentSnapshot result =
        await Firestore.instance.collection("users").document(widget.uid).get();
    List temp = result.data['courses'];
    setState(() => temp.forEach((elem) => {
          _selectedCourses.add(CourseInfo(name: elem['name'], crn: elem['crn']))
        }));
  }

  void _goToAddCourses() async {
    final Set<CourseInfo> updatedSelected = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) =>
                AddCoursesPage(selected: _selectedCourses)));
    setState(() {
      _selectedCourses = updatedSelected;
    });
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
            setState(() {
              _selectedCourses.removeWhere((elem) => elem == info);
            });
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
