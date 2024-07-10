import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/placeholder.dart';
import 'package:frontend/path/navigation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScaner extends StatefulWidget {
  const QRScaner({super.key});
  @override
  State<QRScaner> createState() => _QRScanerState();
}

class _QRScanerState extends State<QRScaner> {
  late String endPoint;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black),
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        child: Column(children: [
          Expanded(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Scan QR code",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1),
              )
            ],
          )),
          Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                child: MobileScanner(onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  final Uint8List? image = capture.image;
                  for (final barcode in barcodes) {
                    // debugPrint('Barcode found! ${barcode.rawValue}');
                    setState(() {
                      endPoint = barcode.rawValue!;
                    });
                  }
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ARNavigationPage(
                                endPoint: endPoint,
                              )));
                }),
              )),
          Expanded(
              child: GestureDetector(
                  onTap: () {},
                  child: Container(
                      margin: EdgeInsets.only(top: 10, left: 8, right: 8),
                      padding: EdgeInsets.all(15),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius:
                              BorderRadius.all(Radius.circular(10))))))
        ]),
      ),
    );
  }
}
