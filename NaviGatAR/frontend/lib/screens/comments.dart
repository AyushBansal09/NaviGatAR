import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/placeholder.dart';
import 'package:dio/dio.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:frontend/models/Comments.dart';
import 'package:frontend/models/Museum.dart';
import 'package:frontend/constants.dart';

final dio = Dio();

class CommentsPage extends StatefulWidget {
  const CommentsPage({super.key, required this.id});
  final String id;
  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  Future<Comm> getComments() async {
    var params = {"museumID": widget.id};
    Response data = await dio.get(
        '$apiUrl/api/tourist/commentFeed',
        data: jsonEncode(params));
    print('Reviews ${data.data}');
    Comm cum = Comm.fromJson(data.data);
    return cum;
  }

  late Future<Comm> cm;

  @override
  void initState() {
    cm = getComments();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<Comm?>(
        future: cm,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            Comm? info = snapshot.data;
            if (info != null) {
              List<Comments> data = info.comments ?? [];
              print(data);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 70, left: 15),
                    child: Text('Reviews',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(0),
                      children: data.map((e) {
                        return Container(
                          margin: EdgeInsets.all(10),
                          padding: EdgeInsets.all(15),
                          decoration: BoxDecoration(
                              color: Color(0xff1a1a1a),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  '${e.tourist!.firstName ?? ''} ${e.tourist!.lastName ?? ''}',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xff1ce0e2),
                                      fontWeight: FontWeight.w700)),
                              SizedBox(
                                height: 7,
                              ),
                              RatingBar.builder(
                                initialRating: e.rating!.toDouble(),
                                minRating: 1,
                                direction: Axis.horizontal,
                                allowHalfRating: false,
                                itemCount: 5,
                                itemSize: 18,
                                ignoreGestures: true,
                                itemPadding:
                                    EdgeInsets.symmetric(horizontal: 0.25),
                                itemBuilder: (context, _) => Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                ),
                                onRatingUpdate: (rating) {
                                  print(rating);
                                },
                              ),
                              SizedBox(
                                height: 7,
                              ),
                              Text(e.commentBody ?? '',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white)),
                              SizedBox(
                                height: 5,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  )
                ],
              );
            }
          }
          return Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
      // body: Column(
      //   // mainAxisAlignment: MainAxisAlignment.start,
      //   crossAxisAlignment: CrossAxisAlignment.start,
      //   children: [
      //     SizedBox(
      //       height: 80,
      //     ),
      //     Container(
      //       margin:EdgeInsets.only(left: 15),
      //       child:Text('Reviews', textAlign: TextAlign.left, style:TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w500)),
      //     ),
      //     Expanded(
      //         child: ListView(
      //       padding: const EdgeInsets.all(0),
      //       children: [
              
      //         Container(
      //           margin: EdgeInsets.all(10),
      //           padding: EdgeInsets.all(15),
      //           decoration: BoxDecoration(
      //               color: Color(0xff1a1a1a),
      //               borderRadius: BorderRadius.all(Radius.circular(10))),
      //           child: Column(
      //             crossAxisAlignment: CrossAxisAlignment.start,
      //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //             children: [
      //               Text('Kirito',
      //                   style: TextStyle(
      //                       fontSize: 16,
      //                       color: Color(0xff1ce0e2),
      //                       fontWeight: FontWeight.w700)),
      //               SizedBox(
      //                 height: 7,
      //               ),
      //               RatingBar.builder(
      //                 initialRating: 3,
      //                 minRating: 1,
      //                 direction: Axis.horizontal,
      //                 allowHalfRating: false,
      //                 itemCount: 5,
      //                 itemSize: 18,
      //                 ignoreGestures: true,
      //                 itemPadding: EdgeInsets.symmetric(horizontal: 0.25),
      //                 itemBuilder: (context, _) => Icon(
      //                   Icons.star,
      //                   color: Colors.amber,
      //                 ),
      //                 onRatingUpdate: (rating) {
      //                   print(rating);
      //                 },
      //               ),
      //               SizedBox(
      //                 height: 7,
      //               ),
      //               Text('Nice place to learn 😃',
      //                   style: TextStyle(fontSize: 16, color: Colors.white)),
      //               SizedBox(
      //                 height: 5,
      //               ),
      //             ],
      //           ),
      //         ),
      //         Container(
      //           margin: EdgeInsets.all(10),
      //           padding: EdgeInsets.all(15),
      //           decoration: BoxDecoration(
      //               color: Color(0xff1a1a1a),
      //               borderRadius: BorderRadius.all(Radius.circular(10))),
      //           child: Column(
      //             crossAxisAlignment: CrossAxisAlignment.start,
      //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //             children: [
      //               Text('Eren',
      //                   style: TextStyle(
      //                       fontSize: 16,
      //                       color: Color(0xff1ce0e2),
      //                       fontWeight: FontWeight.w700)),
      //               SizedBox(
      //                 height: 7,
      //               ),
      //               RatingBar.builder(
      //                 initialRating: 4,
      //                 minRating: 1,
      //                 direction: Axis.horizontal,
      //                 allowHalfRating: false,
      //                 itemCount: 5,
      //                 itemSize: 18,
      //                 ignoreGestures: true,
      //                 itemPadding: EdgeInsets.symmetric(horizontal: 0.25),
      //                 itemBuilder: (context, _) => Icon(
      //                   Icons.star,
      //                   color: Colors.amber,
      //                 ),
      //                 onRatingUpdate: (rating) {
      //                   print(rating);
      //                 },
      //               ),
      //               SizedBox(
      //                 height: 7,
      //               ),
      //               Text('Would visit again!',
      //                   style: TextStyle(fontSize: 16, color: Colors.white)),
      //               SizedBox(
      //                 height: 5,
      //               ),
      //             ],
      //           ),
      //         )
      //       ],
      //     ))
      //   ],
      // ),