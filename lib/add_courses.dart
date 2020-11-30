import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'course_info.dart';

class AddCoursesPage extends StatefulWidget {
  final Map<String, Map<String, List<CourseInfo>>> globalCoursesMap;
  final Set<CourseInfo> selected;
  final Set<CourseInfo> removed = Set();
  final Set<CourseInfo> added = Set();

  AddCoursesPage({Key key, this.globalCoursesMap, this.selected})
      : super(key: key);

  @override
  _AddCoursesPageState createState() => _AddCoursesPageState();
}

class _AddCoursesPageState extends State<AddCoursesPage> {
  final firestoreInstance = Firestore.instance;

  String _subjectDropdownValue;
  String _courseDropdownValue;

  @override
  void initState() {
    super.initState();
  }

  void showTooManyCoursesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Container(
          height: 40.0,
          child: ListTile(
            title: Text('Sorry!'),
            subtitle: Padding(
              padding: EdgeInsets.only(top: 5.0),
              child:
                  Text('You are unable to track more than 10 courses at once'),
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
            if (widget.selected.length + 1 < 16) {
              widget.selected.add(course);

              widget.added.add(course);
              widget.removed.remove(course);
            } else {
              showTooManyCoursesDialog();
            }
          }
        });
      },
    );
  }

  Widget _getAllCoursesListView() {
    List<CourseInfo> globalCoursesList = _subjectDropdownValue == null
        ? []
        : _courseDropdownValue == null
            ? (widget.globalCoursesMap[_subjectDropdownValue].values
                .expand((i) => i)
                .toList()
                  ..sort())
            : widget.globalCoursesMap[_subjectDropdownValue]
                [_courseDropdownValue]
      ..sort();
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
                items: ['', ...widget.globalCoursesMap.keys.toList()..sort()]
                    .map((value) {
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
                    : [
                        '',
                        ...widget.globalCoursesMap[_subjectDropdownValue].keys
                      ].map((value) {
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
      floatingActionButton:
          Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton(
          onPressed: () =>
              Navigator.pop(context, [<CourseInfo>{}, <CourseInfo>{}]),
          tooltip: 'Cancel',
          child: Icon(Icons.cancel),
          heroTag: null,
        ),
        SizedBox(
          height: 10,
        ),
        FloatingActionButton(
          onPressed: () {
            // return updated selected
            Navigator.pop(context, [widget.removed, widget.added]);
          },
          tooltip: 'Save',
          child: Icon(Icons.save),
          heroTag: null,
        ),
      ]),
    );
  }
}
