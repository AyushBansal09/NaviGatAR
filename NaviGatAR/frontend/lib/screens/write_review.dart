import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:frontend/components/default_button.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:frontend/constants.dart';

final dio = Dio();

class Reviews extends StatefulWidget {
  const Reviews({super.key, required this.id});
  final String id;
  @override
  State<Reviews> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<Reviews> {
  void save() async {
    print('Museum id is ${widget.id}');
    print('userId is ${uid}');
    print('comment is ${reviews}');
    print('rating is ${rate}');
    var params = {
      "museumID": widget.id,
      "userID": uid,
      "commentBody": reviews,
      "rating": rate
    };
    Response response = await dio.post(
        '$apiUrl/api/tourist/createComment',
        data: jsonEncode(params));
    print('After post res is ${response.data}');
  }

  final _formKey = GlobalKey<FormState>();
  final user = Hive.box('user');
  late String uid;
  String? reviews;
  double? rate;

  void initState() {
    uid = user.get('id');
    print(uid);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: Container(
            margin: EdgeInsets.only(left: 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                margin: EdgeInsets.only(
                  top: 70,
                ),
                child: Text('Add a review',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w600)),
              ),
              Container(
                margin: EdgeInsets.only(
                  top: 15,
                ),
                child: Text('How was your experience at this location?',
                    style: TextStyle(
                        color: Color(0xfffa256a),
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
              ),
              SizedBox(height: 20),
              Container(
                margin: EdgeInsets.only(top: 10, left: 8, right: 8),
                padding: EdgeInsets.all(6),
                // alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: Color(0xfffa256a),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                child: RatingBar.builder(
                  initialRating: 0,
                  minRating: 0,
                  direction: Axis.horizontal,
                  allowHalfRating: false,
                  itemCount: 5,
                  itemSize: 20,
                  itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
                  itemBuilder: (context, _) => Icon(
                    Icons.star,
                    color: Colors.amber,
                  ),
                  onRatingUpdate: (rating) {
                    setState(() {
                      rate = rating;
                    });
                    // print(rate);
                  },
                ),
              ),
              SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      maxLines: null,
                      minLines: 6,
                      style: TextStyle(color: Colors.white),
                      // obscureText: true,
                      // onSaved: (newValue) => reviews,
                      onChanged: (value) {
                        setState(() {
                          reviews = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: "Write your review here....",
                        filled: true,
                        fillColor: Color(0xff1a1a1a),
                        labelStyle: TextStyle(color: Color(0xfffa256a)),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    Container(
                        child: DefaultButton(
                            text: 'Submit',
                            press: () {
                              save();
                            }))
                  ],
                ),
              )
            ])));
  }
}
