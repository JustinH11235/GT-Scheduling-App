import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'register.dart';
import 'splash.dart';
import 'login.dart';
import 'home.dart';
import 'add_courses.dart';
import 'email_verification.dart';
import 'password_reset.dart';

// TODO: Add Firebase Cloud Messaging to yaml and main.dart and integrate
void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'GT Scheduler',
        theme: ThemeData(
          primarySwatch: Colors.purple,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: SplashPage(),
        routes: <String, WidgetBuilder>{
          '/home': (BuildContext context) => HomePage(),
          '/add_courses': (BuildContext context) => AddCoursesPage(),
          '/login': (BuildContext context) => LoginPage(),
          '/register': (BuildContext context) => RegisterPage(),
          '/email_verification': (BuildContext context) =>
              EmailVerificationPage(),
          '/password_reset.dart': (BuildContext context) => PasswordResetPage(),
        });
  }
}
