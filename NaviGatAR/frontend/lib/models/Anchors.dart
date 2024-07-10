import 'dart:convert';

Welcome welcomeFromJson(String str) => Welcome.fromJson(json.decode(str));

String welcomeToJson(Welcome data) => json.encode(data.toJson());

class Welcome {
    Welcome({
        required this.aranchor,
    });

    List<Aranchor> aranchor;

    factory Welcome.fromJson(Map<String, dynamic> json) => Welcome(
        aranchor: List<Aranchor>.from(json["Aranchor"].map((x) => Aranchor.fromJson(x))),
    );

    Map<String, dynamic> toJson() => {
        "Aranchor": List<dynamic>.from(aranchor.map((x) => x.toJson())),
    };
}

class Aranchor {
    Aranchor({
        required this.type,
        required this.transformation,
        required this.name,
        required this.childNodes,
        this.cloudanchorid,
        required this.ttl,
    });

    int type;
    List<double> transformation;
    String name;
    List<String> childNodes;
    dynamic cloudanchorid;
    int ttl;

    factory Aranchor.fromJson(Map<String, dynamic> json) => Aranchor(
        type: json["type"],
        transformation: List<double>.from(json["transformation"].map((x) => x?.toDouble())),
        name: json["name"],
        childNodes: List<String>.from(json["childNodes"].map((x) => x)),
        cloudanchorid: json["cloudanchorid"],
        ttl: json["ttl"],
    );

    Map<String, dynamic> toJson() => {
        "type": type,
        "transformation": List<dynamic>.from(transformation.map((x) => x)),
        "name": name,
        "childNodes": List<dynamic>.from(childNodes.map((x) => x)),
        "cloudanchorid": cloudanchorid,
        "ttl": ttl,
    };
}