import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  RegisterPage({Key key}) : super(key: key);

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final GlobalKey<FormState> _registerFormKey = GlobalKey<FormState>();
  final _autoValidate = true;
  TextEditingController emailInputController;
  TextEditingController pwdInputController;
  TextEditingController confirmPwdInputController;
  String _incorrectMsgText = "";
  bool _showIncorrectMsg = false;

  @override
  initState() {
    emailInputController = new TextEditingController();
    pwdInputController = new TextEditingController();
    confirmPwdInputController = new TextEditingController();
    super.initState();
  }

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

  String pwdValidator(String value) {
    if (value.length < 8) {
      return 'Password must be longer than 8 characters';
    } else {
      return null;
    }
  }

  String confirmPwdValidator(String value) {
    if (value.length < 8) {
      return 'Password must be longer than 8 characters';
    } else if (pwdInputController.text != confirmPwdInputController.text) {
      return 'Passwords must match';
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Register"),
        ),
        body: Container(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
                child: Form(
              key: _registerFormKey,
              child: Column(
                children: <Widget>[
                  TextFormField(
                    decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: "george.p.burdell@gmail.com"),
                    controller: emailInputController,
                    keyboardType: TextInputType.emailAddress,
                    validator: emailValidator,
                    autovalidate: _autoValidate,
                    onChanged: (String str) {
                      setState(() {
                        _showIncorrectMsg = false;
                      });
                    },
                  ),
                  TextFormField(
                    decoration: InputDecoration(
                        labelText: 'Password', hintText: "********"),
                    controller: pwdInputController,
                    obscureText: true,
                    validator: pwdValidator,
                    autovalidate: _autoValidate,
                    onChanged: (String str) {
                      setState(() {
                        _showIncorrectMsg = false;
                      });
                    },
                  ),
                  TextFormField(
                    decoration: InputDecoration(
                        labelText: 'Confirm Password', hintText: "********"),
                    controller: confirmPwdInputController,
                    obscureText: true,
                    validator: confirmPwdValidator,
                    autovalidate: _autoValidate,
                    onChanged: (String str) {
                      setState(() {
                        _showIncorrectMsg = false;
                      });
                    },
                  ),
                  Visibility(
                    child: Text(_incorrectMsgText,
                        style: TextStyle(color: Colors.red)),
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    visible: _showIncorrectMsg,
                  ),
                  RaisedButton(
                    child: Text("Register"),
                    color: Theme.of(context).primaryColor,
                    textColor: Colors.white,
                    onPressed: () {
                      if (_registerFormKey.currentState.validate()) {
                        FirebaseAuth.instance
                            .createUserWithEmailAndPassword(
                                email: emailInputController.text,
                                password: pwdInputController.text)
                            .then((currentUser) => Firestore.instance
                                    .collection("users")
                                    // .document(currentUser.uid)
                                    .document(currentUser.user.uid)
                                    .setData({
                                  // "uid": currentUser.uid,
                                  "uid": currentUser.user.uid,
                                  "email": emailInputController.text,
                                  "courses": List(),
                                  "tokens": List(),
                                }).then((result) {
                                  // currentUser
                                  currentUser.user.sendEmailVerification();
                                  // Navigator.of(context).pop(),
                                  Navigator.pushReplacementNamed(
                                      context, "/email_verification");
                                  emailInputController.clear();
                                  pwdInputController.clear();
                                  confirmPwdInputController.clear();
                                }).catchError((err) {
                                  // Error adding to database
                                  // print(err);
                                }))
                            .catchError((err) {
                          // Error creating FirebaseAuth user
                          // print(err);
                          setState(() {
                            _incorrectMsgText =
                                "Unable to create account, email may already be in use";
                            _showIncorrectMsg = true;
                          });
                        });
                      } else {
                        // Validation failed
                        setState(() {
                          _incorrectMsgText = "Invalid email and/or password";
                          _showIncorrectMsg = true;
                        });
                      }
                    },
                  ),
                  Divider(),
                  Text("Already have an account?"),
                  FlatButton(
                    child: Text("Login here!"),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  )
                ],
              ),
            ))));
  }
}
