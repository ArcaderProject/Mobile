import 'json.dart';

const int kTotalBinds = 16;

class ControllerProfile {
  final String id;
  final String name;
  final bool isDefault;
  final int itemCount;

  final Map<String, Map<String, dynamic>> bindings;

  ControllerProfile({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.itemCount,
    required this.bindings,
  });

  factory ControllerProfile.fromJson(Map<String, dynamic> json) {
    final rawBindings = json['bindings'];
    final bindings = <String, Map<String, dynamic>>{};
    if (rawBindings is Map) {
      rawBindings.forEach((player, binds) {
        if (binds is Map) {
          bindings[player.toString()] = binds.cast<String, dynamic>();
        }
      });
    }
    return ControllerProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isDefault: jsonTruthy(json['is_default']),
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      bindings: bindings,
    );
  }

  String get bindingsSummary {
    final players = bindings.keys.toList()..sort();
    if (players.isEmpty) return 'Not configured yet';
    return players
        .map((p) => 'P$p: ${bindings[p]?.length ?? 0}/$kTotalBinds')
        .join('  ·  ');
  }
}
