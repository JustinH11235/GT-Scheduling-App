import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PasswordResetPage extends StatelessWidget {
  final GlobalKey<FormState> _pwdResetFormKey = GlobalKey<FormState>();
  final TextEditingController emailInputController =
      new TextEditingController();

  String emailValidator(String value) {
    Pattern pattern =
        r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
    RegExp regex = new RegExp(pattern);
    if (!regex.hasMatch(value)) {
      return 'Please input a valid email';
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Reset Password')),
        body: Center(
            child: Column(
          children: [
            Text('Forgot your password?'),
            Text(
                'Please input your email to receive a password reset link sent to your email.'),
            Container(
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                    child: Form(
                        key: _pwdResetFormKey,
                        child: Column(children: [
                          TextFormField(
                            decoration: InputDecoration(
                                labelText: 'Email',
                                hintText: "george.p.burdell@gmail.com"),
                            controller: emailInputController,
                            keyboardType: TextInputType.emailAddress,
                            validator: emailValidator,
                            autovalidate: true,
                          ),
                          FlatButton(
                              child: Text(
                                "Send Password Reset",
                              ),
                              onPressed: () async {
                                if (_pwdResetFormKey.currentState.validate()) {
                                  await FirebaseAuth.instance
                                      .sendPasswordResetEmail(
                                          email: emailInputController.text);
                                  FocusManager.instance.primaryFocus.unfocus();
                                } else {
                                  // Invalid email format...
                                }
                              })
                        ])))),
            Divider(),
            Text("Once you're done Login again below."),
            FlatButton(
              child: Text("Login"),
              onPressed: () {
                // FirebaseAuth.instance.currentUser().then((currentUser) async {
                //   if (currentUser != null) {
                //     await currentUser.reload();
                //   }
                // }).catchError((err) => print(err));
                Navigator.of(context).pop();
                // Navigator.pushNamedAndRemoveUntil(
                //     context, "/login", (Route<dynamic> route) => false);
              },
            ),
          ],
        )));
  }
}
