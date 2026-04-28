import 'dart:convert';

class SshConnection {
  const SshConnection({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    this.password,
    this.privateKey,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;

  bool get usesPassword => privateKey == null || privateKey!.trim().isEmpty;

  SshConnection copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? privateKey,
  }) {
    return SshConnection(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'privateKey': privateKey,
    };
  }

  factory SshConnection.fromJson(Map<String, dynamic> json) {
    return SshConnection(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      username: json['username'] as String,
      password: json['password'] as String?,
      privateKey: json['privateKey'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  factory SshConnection.decode(String value) {
    return SshConnection.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }
}
