class ARAnchor {
  List<ARTransformation>? aRTransformation;

  ARAnchor({this.aRTransformation});

  ARAnchor.fromJson(Map<String, dynamic> json) {
    if (json['ARTransformation'] != null) {
      aRTransformation = <ARTransformation>[];
      json['ARTransformation'].forEach((v) {
        aRTransformation!.add(new ARTransformation.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.aRTransformation != null) {
      data['ARTransformation'] =
          this.aRTransformation!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class ARTransformation {
  int? type;
  List<double>? transformation;
  String? name;
  List<String>? childNodes;
  Null? cloudanchorid;
  int? ttl;

  ARTransformation(
      {this.type,
      this.transformation,
      this.name,
      this.childNodes,
      this.cloudanchorid,
      this.ttl});

  ARTransformation.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    transformation = json['transformation'].cast<double>();
    name = json['name'];
    childNodes = json['childNodes'].cast<String>();
    cloudanchorid = json['cloudanchorid'];
    ttl = json['ttl'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['type'] = this.type;
    data['transformation'] = this.transformation;
    data['name'] = this.name;
    data['childNodes'] = this.childNodes;
    data['cloudanchorid'] = this.cloudanchorid;
    data['ttl'] = this.ttl;
    return data;
  }
}