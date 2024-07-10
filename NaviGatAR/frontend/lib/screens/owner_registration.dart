import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:frontend/components/custom_surfix_icon.dart';
import 'package:frontend/screens/museum_registration.dart';
import 'package:frontend/screens/owner_login.dart';
import 'package:frontend/screens/sign_in/components/sign_form.dart';
import 'package:frontend/screens/sign_in/sign_in_screen.dart';
import 'package:frontend/screens/write_review.dart';
import 'package:frontend/models/Desc.dart';
import 'package:frontend/constants.dart';

final dio = Dio();

class Owner extends StatefulWidget {
  Owner({Key? key}) : super(key: key);
  @override
  _Owner createState() => _Owner();
}

class _Owner extends State<Owner> {
  final _formKey = GlobalKey<FormState>();
  String? email;
  String? password;
  String? mobile;
  String? lname;
  String? fname;
  String? id;

  Future<void> save() async {
    var params = {
      "email": email,
      "password": password,
      "firstName": fname,
      "mobileNum": mobile,
      "lastName": lname,
    };

    Response response = await dio.post('$apiUrl/api/museumOwner/register',
        data: jsonEncode(params));
    print('RESPONSE ID: ${response.data['id']}');
    setState(() {
      print('RESPONSE ID IN SET STATE: ${response.data['id']}');
      id = response.data['id'];
      print('RESPONSE ID AFTER ASSIGN: ${id}');
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
                  Text('Hello, there!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w600)),
                  Text('Enlist yourself as a campus owner',
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
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
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
                      onTap: () async {
                        await save();
                        print('OWNER ID AFTER SAVE CALL: $id');
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    MuseumRegistration(oid: id)));
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
                          ))),
                  SizedBox(
                    height: 30,
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) => Login()));
                    },
                    child: Container(
                        child: Text("Already have an account? Sign in now",
                            style: TextStyle(
                                color: Color(
                                  0xfffa256a,
                                ),
                                fontSize: 15))),
                  ),
                ]))
          ],
        ));
  }
}
