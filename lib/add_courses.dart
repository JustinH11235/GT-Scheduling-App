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
  final Map<String, Map<String, List<CourseInfo>>> globalCoursesMap = Map();

  String _subjectDropdownValue;
  String _courseDropdownValue;

  @override
  void initState() {
    super.initState();
    print('add_courses init state happened');

    populateGlobalCourses();
  }

  void populateGlobalCourses() async {
    DocumentSnapshot termIDSnapshot = await firestoreInstance
        .collection("globalCourses")
        .document("currentTerm")
        .get();
    int termID = termIDSnapshot.data["currentTerm"].toInt();

    DocumentSnapshot globalCoursesSnapshot = await firestoreInstance
        .collection("globalCourses")
        .document(termID.toString())
        .get();

    setState(() {
      globalCoursesSnapshot.data['subjects'].forEach((subject) {
        final String subjectNameInitials = subject['nameInitials'];
        globalCoursesMap[subjectNameInitials] = Map<String, List<CourseInfo>>();
        subject['courses'].forEach((course) {
          final String courseNumber = course['number'].toString();
          globalCoursesMap[subjectNameInitials][courseNumber] =
              List<CourseInfo>();
          course['sections'].forEach((section) {
            globalCoursesMap[subjectNameInitials][courseNumber].add(CourseInfo(
                term: termID,
                crn: section['crn'],
                name:
                    "$subjectNameInitials $courseNumber - ${section['letter']}"));
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
    List<CourseInfo> globalCoursesList = _subjectDropdownValue == null
        ? []
        : _courseDropdownValue == null
            ? globalCoursesMap[_subjectDropdownValue]
                .values
                .expand((i) => i)
                .toList()
            : globalCoursesMap[_subjectDropdownValue][_courseDropdownValue];
    return ListView.builder(
        padding: EdgeInsets.all(16.0),
        itemCount: globalCoursesList.length,
        itemBuilder: (context, i) {
          return Column(children: [
            _buildAllCoursesRow(globalCoursesList[i]),
            Divider(),
          ]);
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Courses'),
        automaticallyImplyLeading: false,
      ),
      body: Column(children: [
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DropdownButton<String>(
                value: _subjectDropdownValue,
                hint: Text('Subject'),
                items: ['', ...globalCoursesMap.keys].map((value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Container(
                      width: 100,
                      child: new Text(
                        value.isEmpty ? 'Subject' : value,
                        style: TextStyle(
                            color: value.isEmpty
                                ? Theme.of(context).unselectedWidgetColor
                                : Colors.black),
                      ),
                    ),
                  );
                }).toList(growable: false),
                onChanged: (String val) {
                  setState(() {
                    _subjectDropdownValue = val.isEmpty ? null : val;
                    _courseDropdownValue = null;
                  });
                },
              ),
              DropdownButton<String>(
                value: _courseDropdownValue,
                hint: Text('Course #'),
                items: _subjectDropdownValue == null
                    ? []
                    : ['', ...globalCoursesMap[_subjectDropdownValue].keys]
                        .map((value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Container(
                            width: 100,
                            child: new Text(
                              value.isEmpty ? 'Course #' : value,
                              style: TextStyle(
                                  color: value.isEmpty
                                      ? Theme.of(context).unselectedWidgetColor
                                      : Colors.black),
                            ),
                          ),
                        );
                      }).toList(growable: false),
                onChanged: (String val) {
                  setState(() {
                    _courseDropdownValue = val.isEmpty ? null : val;
                  });
                },
              ),
            ]),
        Expanded(
          child: _getAllCoursesListView(),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(
            context, [widget.removed, widget.added]), // return updated selected
        tooltip: 'Back to Home',
        child: Icon(Icons.save),
      ),
    );
  }
}
