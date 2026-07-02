import 'json.dart';

class AppItem {
  final String id;
  final String name;
  final String type;
  final String? url;
  final String? userAgent;
  final String? exec;
  final List<String> args;
  final bool hasIcon;
  final bool enabled;
  final int? position;

  AppItem({
    required this.id,
    required this.name,
    required this.type,
    this.url,
    this.userAgent,
    this.exec,
    this.args = const [],
    this.hasIcon = false,
    this.enabled = true,
    this.position,
  });

  factory AppItem.fromJson(Map<String, dynamic> json) => AppItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Unknown',
        type: json['type'] as String? ?? 'web',
        url: json['url'] as String?,
        userAgent: json['userAgent'] as String?,
        exec: json['exec'] as String?,
        args: (json['args'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        hasIcon: jsonTruthy(json['icon']),
        enabled: jsonTruthy(json['enabled']),
        position: json['position'] is int ? json['position'] as int : null,
      );

  String get target => type == 'web'
      ? (url ?? '')
      : [exec, ...args].whereType<String>().where((s) => s.isNotEmpty).join(' ');

  bool get isWeb => type == 'web';
}
