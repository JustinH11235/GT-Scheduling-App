import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  final String title;
  final String uid;

  HomePage({Key key, this.title, this.uid}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Set<String> _selectedCourses = Set();

  void _goToAddCourses() {
    Navigator.pushNamed(context, "/add_courses");
  }

  Widget _getSelectedCoursesListView() {
    final tiles = _selectedCourses.map(
      (String word) {
        return ListTile(
          title: Text(
            word,
          ),
          trailing: Icon(
            Icons.delete,
            color: Colors.grey,
          ),
          onTap: () {
            setState(() {
              if (_selectedCourses.contains(word)) {
                _selectedCourses.remove(word);
              } else {
                _selectedCourses.add(word);
              }
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
        title: Text(widget.title), //temp
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
