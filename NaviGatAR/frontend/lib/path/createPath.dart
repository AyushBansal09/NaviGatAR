import 'dart:convert';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/src/material/colors.dart';
import 'package:frontend/constants.dart';

final dio = Dio();

class ObjectGesturesWidget extends StatefulWidget {
  final String museumId;
  ObjectGesturesWidget({Key? key, required this.museumId}) : super(key: key);
  @override
  _ObjectGesturesWidgetState createState() => _ObjectGesturesWidgetState();
}

class _ObjectGesturesWidgetState extends State<ObjectGesturesWidget> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  List<ARNode> nodes = [];
  List<ARAnchor> anchors = [];

  // List nodes = [];
  // List anchors = [];

  @override
  void dispose() {
    super.dispose();
    arSessionManager!.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color(0xff000000),
        appBar: AppBar(
          title: const Text('AR Navigation'),
          backgroundColor: Color(0xff000000),
        ),
        body: Container(
            padding: const EdgeInsets.all(16),
            child: Stack(children: [
              ARView(
                onARViewCreated: onARViewCreated,
                planeDetectionConfig:
                    PlaneDetectionConfig.horizontalAndVertical,
              ),
              Align(
                alignment: FractionalOffset.bottomCenter,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: placeduck,
                          child: const Text("Add Node"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xff1ce0e2)),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: removeLastNode,
                          child: const Text("Remove Last Node"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xff1ce0e2)),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onUpload,
                          child: const Text("Upload Path 🚀"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xff1ce0e2)),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onFetchARNodes,
                          child: const Text("Get Path"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xff1ce0e2)),
                        ),
                      ),
                    ]),
              )
            ])));
  }

  void onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    this.arSessionManager!.onInitialize(
          showFeaturePoints: false,
          showPlanes: true,
          customPlaneTexturePath: "Images/triangle.png",
          showWorldOrigin: true,
          handlePans: true,
          handleRotation: true,
        );
    this.arObjectManager!.onInitialize();

    this.arSessionManager!.onPlaneOrPointTap = onPlaneOrPointTapped;
    this.arObjectManager!.onPanStart = onPanStarted;
    this.arObjectManager!.onPanChange = onPanChanged;
    this.arObjectManager!.onPanEnd = onPanEnded;
    this.arObjectManager!.onRotationStart = onRotationStarted;
    this.arObjectManager!.onRotationChange = onRotationChanged;
    this.arObjectManager!.onRotationEnd = onRotationEnded;
  }

  void testConn() async {
    var res = await dio.get("http://localhost:8080");
    print(res.data);
  }

  void onUpload() async {
    var params = {
      "museumID": widget.museumId,
      "arAnchorList": anchors
    };

    var res =
        await dio.post("$apiUrl/api/path/uploadPath", data: jsonEncode(params));
    print(res);
    onRemoveEverything();
  }

  void onFetchARNodes() async {
    var res =
        await dio.get("$apiUrl/api/path/getPath/${widget.museumId}");

    print(res.data[0]["transformation"]);

    var newNodeSrc = ARNode(
        type: NodeType.localGLTF2,
        uri:
        "assets/icons/src.gltf",
        scale: Vector3(0.9 * 2, 0.9 * 2, 0.9 * 2),
        position: Vector3(0.011439, -0.00871425, -0.5),
        rotation: Vector4(0.534616, -0.525168, -0.468367, 0));

    var newNode = ARNode(
        type: NodeType.localGLTF2,
        uri:
            "assets/icons/scene.gltf",
        scale: Vector3(0.9, 0.9, 0.9),
        position: Vector3(0.011439, -0.00871425, -0.5),
        rotation: Vector4(0.534616, -0.525168, -0.468367, 0));

    var newNodeDst = ARNode(
        type: NodeType.localGLTF2,
        uri:
        "assets/icons/dest.gltf",
        scale: Vector3(0.9 * 2, 0.9 * 2, 0.9 * 2),
        position: Vector3(0.011439, -0.00871425, -0.5),
        rotation: Vector4(0.534616, -0.525168, -0.468367, 0));

    for (int i = 0; i < res.data.length; i++) {
      var x = res.data[i]["transformation"];
      var anchor = ARPlaneAnchor(
          transformation: Matrix4(
              x[0].toDouble(),
              x[1].toDouble(),
              x[2].toDouble(),
              x[3].toDouble(),
              x[4].toDouble(),
              x[5].toDouble(),
              x[6].toDouble(),
              x[7].toDouble(),
              x[8].toDouble(),
              x[9].toDouble(),
              x[10].toDouble(),
              x[11].toDouble(),
              x[12].toDouble(),
              x[13].toDouble(),
              x[14].toDouble(),
              x[15].toDouble()));
      await arAnchorManager!.addAnchor(anchor);
      if(i == res.data.length - 1) {
        await arObjectManager!.addNode(newNodeDst, planeAnchor: anchor);
      }
      else if(i == 0) {
        await arObjectManager!.addNode(newNodeSrc, planeAnchor: anchor);
      }
      else {
        await arObjectManager!.addNode(newNode, planeAnchor: anchor);
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> removeLastNode() async {
    print("removeLastNode");
    if (nodes.isNotEmpty && anchors.isNotEmpty) {
      print("inside if in REMOVE LAST NODE");
      // Remove the last node from the AR session and the list
      await arObjectManager!.removeNode(nodes.last);
      nodes.removeLast();

      // Remove the associated anchor from the AR session and the list
      await arAnchorManager!.removeAnchor(anchors.last);
      anchors.removeLast();
    }
  }

  Future<void> placeduck() async {
    var x = await arSessionManager!.getCameraPose() ??
        Matrix4(
            0.999755322933197,
            -1.6543612251060553e-24,
            -0.022120321169495583,
            -0.0002655917778611183,
            -1.8874905002255505e-18,
            1.0,
            -8.530755347162247e-17,
            -0.4026282727718353,
            0.022120321169495583,
            8.532843812772821e-17,
            0.999755322933197,
            -0.8169512748718262,
            0.0,
            0.0,
            0.0,
            1.0);
    var anchor = ARPlaneAnchor(transformation: x);
    arAnchorManager!.addAnchor(anchor);

    var newNode = ARNode(
        type: NodeType.localGLTF2,
        uri:
            "assets/icons/scene.gltf",
        scale: Vector3(0.9, 0.9, 0.9),
        position: Vector3(0.011439, -0.00871425, -0.5),
        rotation: Vector4(0.534616, -0.525168, -0.468367, 0));
    nodes.add(newNode);
    this.arObjectManager!.addNode(newNode, planeAnchor: anchor);
    bool? didAddAnchor =
        await this.arObjectManager!.addNode(newNode, planeAnchor: anchor);
    if (didAddAnchor!) {
      anchors.add(anchor);
    }
  }

  Future<void> onRemoveEverything() async {
    /*nodes.forEach((node) {
      this.arObjectManager.removeNode(node);
    });*/
    anchors.forEach((anchor) {
      this.arAnchorManager!.removeAnchor(anchor);
    });
    anchors = [];
  }

  Future<void> onPlaneOrPointTapped(
      List<ARHitTestResult> hitTestResults) async {
    var singleHitTestResult = hitTestResults.firstWhere(
        (hitTestResult) => hitTestResult.type == ARHitTestResultType.plane);
    if (singleHitTestResult != null) {
      var newAnchor =
          ARPlaneAnchor(transformation: singleHitTestResult.worldTransform);
      print("Anchor location:${singleHitTestResult.worldTransform}");
      bool? didAddAnchor = await this.arAnchorManager!.addAnchor(newAnchor);
      if (didAddAnchor!) {
        this.anchors.add(newAnchor);
        // Add note to anchor
        var newNode = ARNode(
            type: NodeType.localGLTF2,
            uri:
                "assets/icons/scene.gltf",
            scale: Vector3(0.9, 0.9, 0.9),
            position: Vector3(0.0, 0.0, 0.0),
            rotation: Vector4(1.0, 0.0, 0.0, 0.0));
        bool? didAddNodeToAnchor =
            await arObjectManager!.addNode(newNode, planeAnchor: newAnchor);
        if (didAddNodeToAnchor!) {
          nodes.add(newNode);
          print("this is a node = >${nodes}");
          print("The location is :${ARLocationManager().currentLocation}");
        } else {
          this.arSessionManager!.onError("Adding Node to Anchor failed");
        }
      } else {
        this.arSessionManager!.onError("Adding Anchor failed");
      }
    }
  }

  onPanStarted(String nodeName) {
    print("Started panning node " + nodeName);
  }

  onPanChanged(String nodeName) {
    print("Continued panning node " + nodeName);
  }

  onPanEnded(String nodeName, Matrix4 newTransform) {
    print("Ended panning node " + nodeName);
    final pannedNode =
        this.nodes.firstWhere((element) => element.name == nodeName);

    /*
    * Uncomment the following command if you want to keep the transformations of the Flutter representations of the nodes up to date
    * (e.g. if you intend to share the nodes through the cloud)
    */
    //pannedNode.transform = newTransform;
  }

  onRotationStarted(String nodeName) {
    print("Started rotating node " + nodeName);
  }

  onRotationChanged(String nodeName) {
    print("Continued rotating node " + nodeName);
  }

  onRotationEnded(String nodeName, Matrix4 newTransform) {
    print("Ended rotating node " + nodeName);
    final rotatedNode =
        this.nodes.firstWhere((element) => element.name == nodeName);

    /*
    * Uncomment the following command if you want to keep the transformations of the Flutter representations of the nodes up to date
    * (e.g. if you intend to share the nodes through the cloud)
    */
    //rotatedNode.transform = newTransform;
  }
}
