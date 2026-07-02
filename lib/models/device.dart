class Device {
  static const int port = 5328;

  final String id;
  String name;
  String host;
  String? token;

  Device({
    required this.id,
    required this.name,
    required this.host,
    this.token,
  });

  String get baseUrl => 'http://$host:$port';
  bool get isAuthenticated => token != null && token!.isNotEmpty;

  Device copyWith({String? name, String? host, String? token}) {
    return Device(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      token: token ?? this.token,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'token': token,
      };

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Arcader',
        host: json['host'] as String,
        token: json['token'] as String?,
      );
}
