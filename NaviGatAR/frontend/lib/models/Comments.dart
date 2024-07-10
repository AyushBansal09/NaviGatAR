class Comm {
  List<Comments>? comments;

  Comm({this.comments});

  Comm.fromJson(Map<String, dynamic> json) {
    if (json['comments'] != null) {
      comments = <Comments>[];
      json['comments'].forEach((v) {
        comments!.add(new Comments.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.comments != null) {
      data['comments'] = this.comments!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Comments {
  String? id;
  String? museumID;
  String? commentBody;
  String? datePosted;
  int? rating;
  Tourist? tourist;

  Comments(
      {this.id,
      this.museumID,
      this.commentBody,
      this.datePosted,
      this.rating,
      this.tourist});

  Comments.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    museumID = json['museumID'];
    commentBody = json['commentBody'];
    datePosted = json['datePosted'];
    rating = json['rating'];
    tourist =
        json['tourist'] != null ? new Tourist.fromJson(json['tourist']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['museumID'] = this.museumID;
    data['commentBody'] = this.commentBody;
    data['datePosted'] = this.datePosted;
    data['rating'] = this.rating;
    if (this.tourist != null) {
      data['tourist'] = this.tourist!.toJson();
    }
    return data;
  }
}

class Tourist {
  String? firstName;
  String? lastName;

  Tourist({this.firstName, this.lastName});

  Tourist.fromJson(Map<String, dynamic> json) {
    firstName = json['firstName'];
    lastName = json['lastName'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['firstName'] = this.firstName;
    data['lastName'] = this.lastName;
    return data;
  }
}