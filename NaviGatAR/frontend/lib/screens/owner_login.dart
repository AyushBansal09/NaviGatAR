import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:frontend/components/custom_surfix_icon.dart';
import 'package:frontend/screens/museum_owner.dart';
import 'package:frontend/screens/museum_registration.dart';
import 'package:frontend/screens/owner_registration.dart';
import 'package:frontend/screens/sign_in/components/sign_form.dart';
import 'package:frontend/screens/sign_in/sign_in_screen.dart';
import 'package:frontend/screens/write_review.dart';
import 'package:frontend/models/Desc.dart';
import 'package:frontend/constants.dart';

final dio = Dio();

class Login extends StatefulWidget {
  Login({Key? key}) : super(key: key);
  @override
  _Login createState() => _Login();
}

class _Login extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  String? email;
  String? password;
  late String id = "";
  late String name = "";
  late String firstName = "";
  late String lastName = "";

  void save() async {
    var params = {
      "email": email,
      "password": password,
    };
    dio
        .post(
            '$apiUrl/api/museumOwner/login',
            data: jsonEncode(params))
        .then((value) => {
              setState(() {
                id = value.data['userData']['museum']['id'];
                name = value.data['userData']['museum']['museumName'];
                firstName = value.data['userData']['firstName'];
                lastName = value.data['userData']['lastName'];
                print("dsvdsv${id}");
                print("dsvdsv${name}");
                print("fname: ${firstName}");
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => MuseumOwnerPage(
                              museumID: id,
                              museumName: name,
                              firstName: firstName,
                              lastName: lastName,
                            )));
              })
            });
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
                  Text('Welcome',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w600)),
                  Text('Sign in as a campus owner',
                      style: TextStyle(
                          color: Color(0xff1ce0e2),
                          fontSize: 15,
                          fontWeight: FontWeight.w400))
                ])),
            SizedBox(height: 100),
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
                  SizedBox(height: 50),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) => Owner()));
                    },
                    child: Container(
                        child: Text("New here? Sign up as an owner now",
                            style: TextStyle(
                                color: Color(
                                  0xfffa256a,
                                ),
                                fontSize: 15))),
                  ),
                  SizedBox(height: 30),
                  GestureDetector(
                      onTap: () {
                        save();
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
