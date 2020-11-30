import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmailVerificationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Verify Email')),
        body: Center(
            child: Column(
          children: [
            Text('Please click the link sent to your email'),
            FlatButton(
              child: Text(
                "Resend Verification Email",
              ),
              onPressed: () {
                FirebaseAuth.instance.currentUser().then((currentUser) {
                  if (currentUser != null) {
                    currentUser.sendEmailVerification();
                  } else {
                    Navigator.pushReplacementNamed(context, "/login");
                  }
                  FocusManager.instance.primaryFocus.unfocus();
                }).catchError((err) {
                  // print(err);
                });
              },
            ),
            Divider(),
            Text("Once you're done Login again below."),
            FlatButton(
              child: Text("Login"),
              onPressed: () {
                FirebaseAuth.instance.currentUser().then((currentUser) async {
                  if (currentUser != null) {
                    await currentUser.reload();
                  }
                }).catchError((err) {
                  // print(err);
                });
                Navigator.pushNamedAndRemoveUntil(
                    context, "/login", (Route<dynamic> route) => false);
              },
            ),
          ],
        )));
  }
}
