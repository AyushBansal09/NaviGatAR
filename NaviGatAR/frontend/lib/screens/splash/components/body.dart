import 'package:flutter/material.dart';
import 'package:frontend/screens/owner_registration.dart';
import '../../../constants.dart';
import '../../../screens/sign_in/sign_in_screen.dart';
import '../../../size_config.dart';

import '../components/splash_content.dart';
import '../../../components/default_button.dart';

class Body extends StatefulWidget {
  @override
  _BodyState createState() => _BodyState();
}

class _BodyState extends State<Body> {
  int currentPage = 0;
  List<Map<String, String>> splashData = [
    {
      "text": "Welcome to NaviGatAR, Let’s Explore!",
      "image": "assets/images/NaviGatAR_Logo.png"
    },
    {
      "text": "We help people navigate within buildings \naround across campus",
      "image": "assets/images/splash_2.png"
    },
    {
      "text": "We help you know about points of interest. \nIn a modern",
      "image": "assets/images/splash_3.png"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: PageView.builder(
                onPageChanged: (value) {
                  setState(() {
                    currentPage = value;
                  });
                },
                itemCount: splashData.length,
                itemBuilder: (context, index) => SplashContent(
                  image: splashData[index]["image"],
                  text: splashData[index]['text'],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: getProportionateScreenWidth(20)),
                child: Column(
                  children: <Widget>[
                    Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        splashData.length,
                        (index) => buildDot(index: index),
                      ),
                    ),
                    // Spacer(flex: 3),
                    SizedBox(height: 30),
                    DefaultButton(
                      text: "Continue as a Student",
                      press: () {
                        Navigator.pushNamed(context, SignInScreen.routeName);
                      },
                    ),
                    // Spacer(flex:3),
                    Spacer(flex: 1),
                    Text('or', style: TextStyle(color: Color(0xfffa256a))),
                    SizedBox(height: 20),
                    DefaultButton(
                      text: "Continue as a Campus Owner",
                      press: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (context) => Owner()));
                      },
                    ),
                    Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AnimatedContainer buildDot({int? index}) {
    return AnimatedContainer(
      duration: kAnimationDuration,
      margin: EdgeInsets.only(right: 5),
      height: 6,
      width: currentPage == index ? 20 : 6,
      decoration: BoxDecoration(
        color: currentPage == index ? kPrimaryColor : Color(0xFFD8D8D8),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
