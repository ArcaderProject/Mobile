import 'json.dart';

class GameList {
  final String id;
  final String name;
  final String type;
  final bool isDefault;
  final int itemCount;

  GameList({
    required this.id,
    required this.name,
    required this.type,
    required this.isDefault,
    required this.itemCount,
  });

  bool get isInclude => type == 'include';

  factory GameList.fromJson(Map<String, dynamic> json) => GameList(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? 'include',
        isDefault: jsonTruthy(json['is_default']),
        itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      );
}
