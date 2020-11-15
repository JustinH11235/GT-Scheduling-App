import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'course_info.dart';

class AddCoursesPage extends StatefulWidget {
  final Set<CourseInfo> selected;
  final Set<CourseInfo> removed = Set();
  final Set<CourseInfo> added = Set();

  AddCoursesPage({Key key, this.selected}) : super(key: key);

  @override
  _AddCoursesPageState createState() => _AddCoursesPageState();
}

class _AddCoursesPageState extends State<AddCoursesPage> {
  final firestoreInstance = Firestore.instance;
  final List<CourseInfo> globalCoursesList = List<CourseInfo>();

  @override
  void initState() {
    super.initState();

    populateGlobalCourses();
  }

  void populateGlobalCourses() async {
    DocumentSnapshot termIDSnapshot = await firestoreInstance
        .collection("globalCourses")
        .document("currentTerm")
        .get();
    int termID = termIDSnapshot.data["currentTerm"];

    DocumentSnapshot globalCoursesSnapshot = await firestoreInstance
        .collection("globalCourses")
        .document(termID.toString())
        .get();

    setState(() {
      globalCoursesSnapshot.data['subjects'].forEach((subject) {
        subject['courses'].forEach((course) {
          course['sections'].forEach((section) {
            globalCoursesList.add(CourseInfo(
                term: termID,
                crn: section['crn'],
                name:
                    "${subject['nameInitials']} ${course['number']} - ${section['letter']}"));
          });
        });
      });
    });
  }

  Widget _buildAllCoursesRow(CourseInfo course) {
    final bool isSelected = widget.selected.contains(course);
    return ListTile(
      title: Text(
        course.name,
      ),
      trailing: Icon(
        isSelected ? Icons.favorite : Icons.favorite_border,
        color: isSelected ? Colors.red : null,
      ),
      onTap: () {
        setState(() {
          if (widget.selected.contains(course)) {
            widget.selected.remove(course);

            widget.removed.add(course);
            widget.added.remove(course);
          } else {
            widget.selected.add(course);

            widget.added.add(course);
            widget.removed.remove(course);
          }
        });
      },
    );
  }

  Widget _getAllCoursesListView() {
    return ListView.builder(
        padding: EdgeInsets.all(16.0),
        itemCount: globalCoursesList.length,
        itemBuilder: (context, i) {
          return Column(
              children: [Divider(), _buildAllCoursesRow(globalCoursesList[i])]);
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Courses'),
        automaticallyImplyLeading: false,
      ),
      body: _getAllCoursesListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(
            context, [widget.removed, widget.added]), // return updated selected
        tooltip: 'Back to Home',
        child: Icon(Icons.save),
      ),
    );
  }
}
