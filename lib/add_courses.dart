import 'package:flutter/material.dart';

import 'course_info.dart';

class AddCoursesPage extends StatefulWidget {
  final Set<CourseInfo> selected;

  AddCoursesPage({Key key, this.selected}) : super(key: key);

  @override
  _AddCoursesPageState createState() => _AddCoursesPageState();
}

class _AddCoursesPageState extends State<AddCoursesPage> {
  final _courses = [
    CourseInfo(name: 'CS 101-A', crn: 101),
    CourseInfo(name: 'CHEM 102-G', crn: 102),
    CourseInfo(name: 'PSYC 100-R', crn: 100),
  ];

  Widget _buildAllCoursesRow(CourseInfo course) {
    final isSelected = widget.selected.singleWhere(
            (elem) => elem.name == course.name && elem.crn == course.crn,
            orElse: () => null) !=
        null;
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
          if (widget.selected.singleWhere(
                  (elem) => elem.name == course.name && elem.crn == course.crn,
                  orElse: () => null) !=
              null) {
            widget.selected.removeWhere(
                (elem) => elem.name == course.name && elem.crn == course.crn);
          } else {
            widget.selected.add(course);
          }
        });
      },
    );
  }

  Widget _getAllCoursesListView() {
    return ListView.builder(
        padding: EdgeInsets.all(16.0),
        itemCount: _courses.length,
        itemBuilder: (context, i) {
          return Column(children: [
            Divider(),
            _buildAllCoursesRow(_courses[i % _courses.length])
          ]);
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Courses')),
      body: _getAllCoursesListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context, widget.selected),
        tooltip: 'Save',
        child: Icon(Icons.save),
      ),
    );
  }
}
