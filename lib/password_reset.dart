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
        body: Container(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
                child: Column(
              children: [
                Text('Forgot your password?'),
                Text('Input your email to receive a password reset link.'),
                Form(
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
                              try {
                                await FirebaseAuth.instance
                                    .sendPasswordResetEmail(
                                        email: emailInputController.text);
                                FocusManager.instance.primaryFocus.unfocus();
                              } catch (err) {
                                // No user found with this email
                                showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Text("Error"),
                                        content: Text(
                                            "No user exists for this email address"),
                                        actions: <Widget>[
                                          FlatButton(
                                            child: Text("Close"),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          )
                                        ],
                                      );
                                    });
                              }
                            } else {
                              // Invalid email format... do nothing.
                              showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text("Error"),
                                      content:
                                          Text("Invalid email and/or password"),
                                      actions: <Widget>[
                                        FlatButton(
                                          child: Text("Close"),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        )
                                      ],
                                    );
                                  });
                            }
                          })
                    ])),
                Divider(),
                Text("Once you're done, Login again below."),
                FlatButton(
                  child: Text("Login"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ))));
  }
}
