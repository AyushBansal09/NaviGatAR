import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../models/Museum.dart';
import 'package:frontend/screens/museum_description.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:frontend/constants.dart';

// import 'package:localstorage/localstorage.dart';

final dio = Dio();

class MuseumList extends StatefulWidget {
  MuseumList({Key? key}) : super(key: key);
  @override
  _MuseumList createState() => _MuseumList();
}

class _MuseumList extends State<MuseumList> {
  Future<Museum> getMuseum() async {
    Response data = await dio.get(
        '$apiUrl/api/tourist/museumsFeed');
    print('User info ${data.data}');
    Museum museum = Museum.fromJson(data.data);
    return museum;
  }

  late Future<Museum> mus;

  final user = Hive.box('user');

  @override
  void initState() {
    mus = getMuseum();
    print('Its ${user.get('id')}');
    super.initState();
  }

  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: FutureBuilder<Museum?>(
          future: mus,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              print(snapshot.data);
              Museum? musInfo = snapshot.data;
              if (musInfo != null) {
                List<Data> data = musInfo.data ?? [];
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: EdgeInsets.only(top: 70, left: 15),
                        child: Text('Campus Locations',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(0),
                          children: data.map((it) {
                            print(it);
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => MuseumDescription(
                                            id: it.id ?? '')));
                              },
                              child: Container(
                                  margin: EdgeInsets.all(10),
                                  padding: EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                      color: Color(0xff1a1a1a),
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(10))),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(it.museumName ?? '',
                                          style: TextStyle(
                                              fontSize: 20,
                                              color: Color(0xfffa256a),
                                              fontWeight: FontWeight.bold)),
                                      SizedBox(
                                        height: 7,
                                      ),
                                      Text('${it.inTime} - ${it.outTime}',
                                          style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.white)),
                                      SizedBox(
                                        height: 5,
                                      ),
                                      Row(
                                          children: it.tags!.map((e) {
                                        return Container(
                                            child: Text(e,
                                                style: TextStyle(
                                                    color: Color(0xff1ce0e2))));
                                      }).toList())
                                    ],
                                  )),
                            );
                          }).toList(),
                        ),
                      )
                    ]);
              }
            }
            return Center(child: CircularProgressIndicator());
          },
        ));
  }
}
