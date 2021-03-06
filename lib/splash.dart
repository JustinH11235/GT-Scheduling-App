import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home.dart';

class SplashPage extends StatefulWidget {
  SplashPage({Key key}) : super(key: key);

  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  initState() {
    super.initState();
    FirebaseAuth.instance
        .currentUser()
        .then((currentUser) => {
              if (currentUser == null || !currentUser.isEmailVerified)
                {Navigator.pushReplacementNamed(context, "/login")}
              else
                {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => HomePage(
                                uid: currentUser.uid,
                              ))).catchError((err) {
                    // print(err);
                  })
                }
            })
        .catchError((err) {
      // print(err);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          child: Text("Loading..."),
        ),
      ),
    );
  }
}
