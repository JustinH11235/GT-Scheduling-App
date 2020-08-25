import 'package:flutter/material.dart';

class AddCoursesPage extends StatefulWidget {
  // final courses;
  // final selected;
  // AddCourses({Key key, this.courses, this.selected}) : super(key: key);

  @override
  _AddCoursesPageState createState() => _AddCoursesPageState();
}

class _AddCoursesPageState extends State<AddCoursesPage> {
  final _courses = [
    'CS 101-A',
    'CHEM 102-G',
    'PSYC 100-R',
    'ENGL 202-A',
    'PHYS 244-J',
    'GT 1000-Y',
    'EAS 2600-A',
    'GT 2000-C',
    'MATH 2550-E',
  ];
  // TODO: pass in current selected from home..., then pass updated back
  Set<String> _selectedCourses = Set();

  Widget _buildAllCoursesRow(String word) {
    final isSelected = _selectedCourses.contains(word);
    return ListTile(
      title: Text(
        word,
      ),
      trailing: Icon(
        isSelected ? Icons.favorite : Icons.favorite_border,
        color: isSelected ? Colors.red : null,
      ),
      onTap: () {
        // setStateAddCoursesPage(() {
        //   if (_selectedCourses.contains(word)) {
        //     _selectedCourses.remove(word);
        //   } else {
        //     _selectedCourses.add(word);
        //   }
        // });
        setState(() {
          if (_selectedCourses.contains(word)) {
            _selectedCourses.remove(word);
          } else {
            _selectedCourses.add(word);
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
    );
  }
}
