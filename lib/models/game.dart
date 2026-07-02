import 'json.dart';

class Game {
  final String id;
  final String name;
  final String filename;
  final String extension;
  final String core;
  final String console;
  final bool hasCover;

  Game({
    required this.id,
    required this.name,
    required this.filename,
    required this.extension,
    required this.core,
    required this.console,
    required this.hasCover,
  });

  factory Game.fromJson(Map<String, dynamic> json) => Game(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Unknown',
        filename: json['filename'] as String? ?? '',
        extension: json['extension'] as String? ?? '',
        core: json['core'] as String? ?? '',
        console: json['console'] as String? ?? '',
        hasCover: jsonTruthy(json['cover_art']),
      );
}

class GameCore {
  final String core;
  final String displayName;
  final String systemName;
  final List<String> extensions;

  GameCore({
    required this.core,
    required this.displayName,
    required this.systemName,
    required this.extensions,
  });

  String get label =>
      displayName.isNotEmpty ? displayName : (systemName.isNotEmpty ? systemName : core);

  factory GameCore.fromJson(Map<String, dynamic> json) => GameCore(
        core: json['core'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        systemName: json['systemname'] as String? ?? '',
        extensions: (json['extensions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

class CoverCandidate {
  final String url;
  final String thumb;

  CoverCandidate({required this.url, required this.thumb});

  factory CoverCandidate.fromJson(Map<String, dynamic> json) => CoverCandidate(
        url: json['url'] as String? ?? '',
        thumb: json['thumb'] as String? ?? json['url'] as String? ?? '',
      );
}

class NowPlaying {
  final bool playing;
  final String? name;
  final String? console;

  NowPlaying({required this.playing, this.name, this.console});

  factory NowPlaying.fromJson(Map<String, dynamic> json) {
    final game = json['game'];
    return NowPlaying(
      playing: json['playing'] == true,
      name: game is Map ? game['name'] as String? : null,
      console: game is Map ? game['console'] as String? : null,
    );
  }

  static NowPlaying idle() => NowPlaying(playing: false);
}
