import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:frontend/components/custom_surfix_icon.dart';
import 'package:frontend/screens/sign_in/components/sign_form.dart';
import 'package:frontend/screens/sign_in/sign_in_screen.dart';
import 'package:frontend/screens/write_review.dart';
import 'package:frontend/models/Desc.dart';
import 'package:frontend/constants.dart';

final dio = Dio();

class Signup extends StatefulWidget {
  Signup({Key? key}) : super(key: key);
  @override
  _Signup createState() => _Signup();
}

class _Signup extends State<Signup> {
  final _formKey = GlobalKey<FormState>();
  String? email;
  String? password;
  String? mobile;
  String? lname;
  String? fname;

  void save() async {
    var params = {
      "email": email,
      "password": password,
      "firstName": fname,
      "mobileNum": mobile,
      "lastName": lname,
    };

    Response response = await dio.post('$apiUrl/api/tourist/register',
        data: jsonEncode(params));
    print('nasnasjn ios r${response.data}');
  }

  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: ListView(
          padding: EdgeInsets.only(left: 10, right: 10, top: 20),
          children: [
            Container(
                margin: EdgeInsets.only(top: 40),
                alignment: Alignment.center,
                child: Column(children: [
                  Text('Hello, there!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w600)),
                  Text('Sign up as a student and start navigating',
                      style: TextStyle(
                          color: Color(0xff1ce0e2),
                          fontSize: 15,
                          fontWeight: FontWeight.w400))
                ])),
            SizedBox(height: 50),
            Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    style: TextStyle(color: Colors.white),
                    // obscureText: true,
                    onSaved: (newValue) => email = newValue,
                    onChanged: (value) {
                      setState(() {
                        email = value;
                      });
                    },
                    decoration: InputDecoration(
                        labelText: "Email Id",
                        filled: true,
                        fillColor: Color(0xff1a1a1a),
                        labelStyle: TextStyle(color: Color(0xfffa256a)),
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                        suffixIcon: Icon(Icons.mail)),
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 20),
                    child: TextFormField(
                      style: TextStyle(color: Colors.white),
                      onSaved: (newValue) => email = newValue,
                      onChanged: (value) {
                        setState(() {
                          mobile = value;
                        });
                      },
                      decoration: InputDecoration(
                          labelText: "Mobile Number",
                          filled: true,
                          fillColor: Color(0xff1a1a1a),
                          labelStyle: TextStyle(color: Color(0xfffa256a)),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                          suffixIcon: Icon(Icons.mobile_friendly)),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 20),
                    child: TextFormField(
                      style: TextStyle(color: Colors.white),
                      obscureText: true,
                      onSaved: (newValue) => email = newValue,
                      onChanged: (value) {
                        setState(() {
                          password = value;
                        });
                      },
                      decoration: InputDecoration(
                          labelText: "Password",
                          filled: true,
                          fillColor: Color(0xff1a1a1a),
                          labelStyle: TextStyle(color: Color(0xfffa256a)),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                          suffixIcon: Icon(Icons.lock)),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 20),
                    child: TextFormField(
                      style: TextStyle(color: Colors.white),
                      onSaved: (newValue) => email = newValue,
                      onChanged: (value) {
                        setState(() {
                          fname = value;
                        });
                      },
                      decoration: InputDecoration(
                          labelText: "First Name",
                          filled: true,
                          fillColor: Color(0xff1a1a1a),
                          labelStyle: TextStyle(color: Color(0xfffa256a)),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                          suffixIcon: Icon(Icons.text_fields_outlined)),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 20),
                    child: TextFormField(
                      style: TextStyle(color: Colors.white),
                      onSaved: (newValue) => email = newValue,
                      onChanged: (value) {
                        setState(() {
                          lname = value;
                        });
                      },
                      decoration: InputDecoration(
                          labelText: "Last Name",
                          filled: true,
                          fillColor: Color(0xff1a1a1a),
                          labelStyle: TextStyle(color: Color(0xfffa256a)),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                          suffixIcon: Icon(Icons.text_fields)),
                    ),
                  ),
                  GestureDetector(
                      onTap: () {
                        save();
                        Navigator.pushNamed(context, SignInScreen.routeName);
                      },
                      child: Container(
                          margin: EdgeInsets.only(top: 20, left: 8, right: 8),
                          padding: EdgeInsets.all(15),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: Color(0xfffa256a),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10))),
                          child: Text(
                            'Submit',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          )))
                ]))
          ],
        ));
  }
}
