import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/placeholder.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:frontend/screens/owner_profile.dart';

import '../path/createPath.dart';
import 'comments.dart';

String mID = "";
String mName = "";

class MuseumOwnerPage extends StatefulWidget {
  MuseumOwnerPage(
      {Key? key,
      required this.museumID,
      required this.museumName,
      required this.firstName,
      required this.lastName})
      : super(key: key);
  final String museumID;
  final String museumName;
  final String firstName;
  final String lastName;
  @override
  State<MuseumOwnerPage> createState() => _MuseumOwnerPageState();
}

class _MuseumOwnerPageState extends State<MuseumOwnerPage> {
  int currentIndex = 0;
  final double _currentSliderValue = 0;

  // @override
  // void initState() {
  //   super.initState();
  //   print("mID from initstate ${mID}");
  //   print("i am initState");
  // }

  @override
  void setState(VoidCallback fn) {
    // TODO: implement setState
    mID = widget.museumID;
    mName = widget.museumName;
    print("from setState ${mID}");

    super.setState(fn);
  }

  @override
  void initState() {
    // TODO: implement initState
    print("in oPage${widget.museumID}");
    mID = widget.museumID;
    mName = widget.museumName;
  }

  @override
  Widget build(BuildContext context) {
    print("mID ${mID}");

    final pages = [
      Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text("AR View"), backgroundColor: Colors.black),
        body: ObjectGesturesWidget(museumId: widget.museumID),
      ),
      Scaffold(
          backgroundColor: Colors.black,
          // appBar: AppBar(
          //   title: Text("Feedback View"),
          //   backgroundColor: Colors.black,
          // ),
          body: CommentsPage(id: widget.museumID)),
      Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text('Your Profile',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w600)),
          backgroundColor: Colors.black,
        ),
        body: ProfileScreen(
          museumID: widget.museumID,
          museumName: widget.museumName,
          firstName: widget.firstName,
          lastName: widget.lastName,
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xff243443),
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.shifting,
        selectedItemColor: const Color(0xff1ce0e2),
        unselectedItemColor: Colors.white,
        currentIndex: currentIndex,
        onTap: (index) => setState(() => {
              currentIndex = index,
              mID = widget.museumID,
              mName = widget.museumName,
            }),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.navigation_rounded),
              label: "Create Path",
              backgroundColor: Colors.black),
          BottomNavigationBarItem(
              icon: Icon(Icons.feed_rounded),
              label: "View Feedback",
              backgroundColor: Colors.black),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_rounded),
              label: "Profile",
              backgroundColor: Colors.black)
        ],
      ),
    );
  }
}
