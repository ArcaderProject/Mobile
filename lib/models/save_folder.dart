import 'game.dart';

class SaveFolder {
  final String uuid;
  final String name;
  final bool isLocked;
  final bool isActive;
  final bool isDefault;

  SaveFolder({
    required this.uuid,
    required this.name,
    required this.isLocked,
    required this.isActive,
    required this.isDefault,
  });

  factory SaveFolder.fromJson(Map<String, dynamic> json) => SaveFolder(
        uuid: json['uuid'] as String? ?? '',
        name: json['name'] as String? ?? '',
        isLocked: json['isLocked'] == true,
        isActive: json['isActive'] == true,
        isDefault: json['isDefault'] == true,
      );
}

class GameSave {
  final String gameId;
  final int fileCount;
  final int totalSize;
  final Game game;

  GameSave({
    required this.gameId,
    required this.fileCount,
    required this.totalSize,
    required this.game,
  });

  factory GameSave.fromJson(Map<String, dynamic> json) => GameSave(
        gameId: json['gameId'] as String? ?? '',
        fileCount: (json['fileCount'] as num?)?.toInt() ?? 0,
        totalSize: (json['totalSize'] as num?)?.toInt() ?? 0,
        game: Game.fromJson((json['game'] as Map?)?.cast<String, dynamic>() ?? {}),
      );
}
