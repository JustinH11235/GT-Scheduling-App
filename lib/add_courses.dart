import 'package:flutter/material.dart';

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
  final _allCourses = [
    CourseInfo(name: 'CS 101-A', crn: 101, term: 202008),
    CourseInfo(name: 'CHEM 102-G', crn: 102, term: 202008),
    CourseInfo(name: 'PSYC 100-R', crn: 100, term: 202008),
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
                  // remove
                  (elem) => elem.name == course.name && elem.crn == course.crn,
                  orElse: () => null) !=
              null) {
            widget.selected.removeWhere(
                (elem) => elem.name == course.name && elem.crn == course.crn);

            widget.removed.add(course);
            widget.added.remove(course);
          } else {
            // add
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
        itemCount: _allCourses.length,
        itemBuilder: (context, i) {
          return Column(children: [
            Divider(),
            _buildAllCoursesRow(_allCourses[i % _allCourses.length])
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
      body: _getAllCoursesListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(
            context, [widget.removed, widget.added]), // ret updates
        tooltip: 'Back to Home',
        child: Icon(Icons.save),
      ),
    );
  }
}
