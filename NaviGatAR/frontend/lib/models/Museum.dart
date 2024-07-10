class Museum {
  List<Data>? data;

  Museum({this.data});

  Museum.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(new Data.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Data {
  String? id;
  String? museumName;
  String? inTime;
  String? outTime;
  List<String>? tags;

  Data({this.museumName, this.inTime, this.outTime, this.tags});

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    museumName = json['museumName'];
    inTime = json['inTime'];
    outTime = json['outTime'];
    tags = json['tags'].cast<String>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['museumName'] = this.museumName;
    data['inTime'] = this.inTime;
    data['outTime'] = this.outTime;
    data['tags'] = this.tags;
    return data;
  }
}