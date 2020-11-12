import 'package:flutter/material.dart';

import 'constants.dart' as Constants;

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
  Widget _buildAllCoursesRow(CourseInfo course) {
    final isSelected = widget.selected.contains(course);
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
        itemCount: Constants.globalCoursesList.length,
        itemBuilder: (context, i) {
          return Column(children: [
            Divider(),
            _buildAllCoursesRow(Constants.globalCoursesList[i])
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
            context, [widget.removed, widget.added]), // return updates
        tooltip: 'Back to Home',
        child: Icon(Icons.save),
      ),
    );
  }
}
