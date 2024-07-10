import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:frontend/path/navigation.dart';
import 'package:frontend/screens/qr_scan.dart';

import 'package:frontend/screens/write_review.dart';
import '../models/Museum.dart';
import 'package:frontend/models/Desc.dart';
import '../path/createPath.dart';
import 'comments.dart';
import 'package:frontend/constants.dart';

final dio = Dio();

class MuseumDescription extends StatefulWidget {
  MuseumDescription({Key? key, required this.id}) : super(key: key);
  final String id;
  static String routeName = "/description";
  @override
  _MuseumDescription createState() => _MuseumDescription();
}

class _MuseumDescription extends State<MuseumDescription> {
  Future<Description> getMuseum() async {
    var params = {"museumID": widget.id};

    Response data = await dio.get('$apiUrl/api/tourist/museumDetail',
        data: jsonEncode(params));
    print('User info ${data.data}');
    Description description = Description.fromJson(data.data);
    return description;
  }

  late Future<Description> desc;

  @override
  void initState() {
    desc = getMuseum();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<Description?>(
          future: desc,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              Description? info = snapshot.data;
              if (info != null) {
                return ListView(
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 10, left: 8, right: 8),
                      padding: EdgeInsets.all(15),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: Color(0xff1a1a1a),
                          borderRadius: BorderRadius.all(Radius.circular(10))),
                      child: Text(info.museumDetails!.museumName ?? '',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 30,
                          )),
                    ),
                    Container(
                        margin: EdgeInsets.only(top: 10, left: 8, right: 8),
                        padding: EdgeInsets.all(15),
                        // alignment: Alignment,
                        decoration: BoxDecoration(
                            color: Color(0xff1a1a1a),
                            borderRadius:
                                BorderRadius.all(Radius.circular(10))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: EdgeInsets.only(bottom: 10),
                              child: Text('About this location',
                                  style: TextStyle(
                                      color: Color(0xfffa256a),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500)),
                            ),
                            Text(info.museumDetails!.aboutMuseum ?? '',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400,
                                  height: 1.5,
                                )),
                            // Spacer();
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    margin: EdgeInsets.symmetric(vertical: 20),
                                    child: Text(
                                      'Timings',
                                      style: TextStyle(
                                          color: Color(0xff1ce0e2),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500),
                                    )),
                                Container(
                                  child: Text(
                                      '${info.museumDetails!.inTime ?? ''} - ${info.museumDetails!.outTime}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w400,
                                        height: 1.5,
                                      )),
                                ),
                              ],
                            ),
                          ],
                        )),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => QRScaner()));
                              },
                              child: Container(
                                  margin: EdgeInsets.only(
                                      top: 10, left: 8, right: 8),
                                  padding: EdgeInsets.all(15),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: Color(0xfffa256a),
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(10))),
                                  child: Text(
                                    'Scan QR ',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 15),
                                  ))),
                        ),
                        Expanded(
                          child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            CommentsPage(id: widget.id)));
                              },
                              child: Container(
                                  margin: EdgeInsets.only(
                                      top: 10, left: 8, right: 8),
                                  padding: EdgeInsets.all(15),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: Color(0xfffa256a),
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(10))),
                                  child: Text(
                                    'View reviews',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 15),
                                  ))),
                        ),
                        Expanded(
                          child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            Reviews(id: widget.id)));
                              },
                              child: Container(
                                  margin: EdgeInsets.only(
                                      top: 10, left: 8, right: 8),
                                  padding: EdgeInsets.all(15),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: Color(0xfffa256a),
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(10))),
                                  child: Text(
                                    'Add a review',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 15),
                                  ))),
                        ),
                      ],
                    ),
                  ],
                );
              }
            }
            return Center(child: CircularProgressIndicator());
          }),
    );
  }
}
