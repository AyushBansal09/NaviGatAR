class Description {
  MuseumDetails? museumDetails;

  Description({this.museumDetails});

  Description.fromJson(Map<String, dynamic> json) {
    museumDetails = json['museumDetails'] != null
        ? new MuseumDetails.fromJson(json['museumDetails'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.museumDetails != null) {
      data['museumDetails'] = this.museumDetails!.toJson();
    }
    return data;
  }
}

class MuseumDetails {
  String? id;
  String? museumName;
  String? inTime;
  String? outTime;
  String? aboutMuseum;
  List<String>? tags;

  MuseumDetails(
      {this.id,
      this.museumName,
      this.inTime,
      this.outTime,
      this.aboutMuseum,
      this.tags});

  MuseumDetails.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    museumName = json['museumName'];
    inTime = json['inTime'];
    outTime = json['outTime'];
    aboutMuseum = json['aboutMuseum'];
    tags = json['tags'].cast<String>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['museumName'] = this.museumName;
    data['inTime'] = this.inTime;
    data['outTime'] = this.outTime;
    data['aboutMuseum'] = this.aboutMuseum;
    data['tags'] = this.tags;
    return data;
  }
}