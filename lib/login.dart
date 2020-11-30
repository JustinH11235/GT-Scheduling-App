import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home.dart';

class LoginPage extends StatefulWidget {
  LoginPage({Key key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final _autoValidate = true;
  String _incorrectMsgText = "";
  bool _showIncorrectMsg = false;
  TextEditingController emailInputController;
  TextEditingController pwdInputController;

  @override
  initState() {
    emailInputController = new TextEditingController();
    pwdInputController = new TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Login"),
        ),
        body: Container(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
                child: Form(
              key: _loginFormKey,
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
                  Visibility(
                    child: Text(_incorrectMsgText,
                        style: TextStyle(color: Colors.red)),
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    visible: _showIncorrectMsg,
                  ),
                  RaisedButton(
                    child: Text("Login"),
                    color: Theme.of(context).primaryColor,
                    textColor: Colors.white,
                    onPressed: () {
                      if (_loginFormKey.currentState.validate()) {
                        FirebaseAuth.instance
                            .signInWithEmailAndPassword(
                                email: emailInputController.text,
                                password: pwdInputController.text)
                            .then((currentUser) => {
                                  if (currentUser.user.isEmailVerified)
                                    {
                                      Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) => HomePage(
                                                    // uid: currentUser.uid,
                                                    uid: currentUser.user.uid,
                                                  ))),
                                      // print('New uid: ' + currentUser.uid),
                                      // print('New uid: ' + currentUser.user.uid),
                                    }
                                  else
                                    {
                                      // User has not verified email...
                                      Navigator.pushReplacementNamed(
                                          context, "/email_verification"),
                                    }
                                })
                            .catchError((err) {
                          // Error logging in
                          setState(() {
                            _incorrectMsgText =
                                "Incorrect email and/or password";
                            _showIncorrectMsg = true;
                          });
                          // print(err);
                        });
                      } else {
                        // Fields not valid
                        setState(() {
                          _incorrectMsgText = "Invalid email and/or password";
                          _showIncorrectMsg = true;
                        });
                      }
                    },
                  ),
                  FlatButton(
                    child: Text("Forgot Password"),
                    onPressed: () {
                      Navigator.pushNamed(context, "/password_reset.dart");
                      FocusManager.instance.primaryFocus.unfocus();
                      pwdInputController.clear();
                      setState(() => _showIncorrectMsg = false);
                    },
                  ),
                  Divider(),
                  Text("Don't have an account yet?"),
                  FlatButton(
                    child: Text("Register here!"),
                    onPressed: () {
                      Navigator.pushNamed(context, "/register");
                      FocusManager.instance.primaryFocus.unfocus();
                      emailInputController.clear();
                      pwdInputController.clear();
                      setState(() => _showIncorrectMsg = false);
                    },
                  ),
                ],
              ),
            ))));
  }
}
