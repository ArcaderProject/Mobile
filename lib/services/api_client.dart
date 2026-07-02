import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/app_config.dart';
import '../models/app_item.dart';
import '../models/coin_status.dart';
import '../models/device.dart';
import '../models/game.dart';
import '../models/game_list.dart';
import '../models/save_folder.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  final Device device;
  final http.Client _http;

  ApiClient(this.device, {http.Client? client}) : _http = client ?? http.Client();

  String get _base => '${device.baseUrl}/api';

  Map<String, String> get _authHeaders =>
      {if (device.token != null) 'Authorization': 'Bearer ${device.token}'};

  Map<String, String> get authImageHeaders => _authHeaders;

  Uri _uri(String path) => Uri.parse('$_base$path');

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final headers = {..._authHeaders, 'Content-Type': 'application/json'};
    final req = http.Request(method, _uri(path))..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);

    late http.StreamedResponse streamed;
    try {
      streamed = await _http.send(req).timeout(timeout);
    } on TimeoutException {
      throw ApiException(0, 'Request timed out');
    } catch (e) {
      throw ApiException(0, 'Network error: $e');
    }
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    dynamic parsed;
    if (res.body.isNotEmpty) {
      try {
        parsed = jsonDecode(res.body);
      } catch (_) {
        parsed = res.body;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return parsed;

    final msg = (parsed is Map && parsed['error'] != null)
        ? parsed['error'].toString()
        : (parsed?.toString().isNotEmpty == true ? parsed.toString() : 'HTTP ${res.statusCode}');
    throw ApiException(res.statusCode, msg);
  }

  Future<dynamic> _get(String path, {Duration? timeout}) =>
      _send('GET', path, timeout: timeout ?? const Duration(seconds: 15));
  Future<dynamic> _post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<dynamic> _put(String path, [Object? body]) => _send('PUT', path, body: body);
  Future<dynamic> _delete(String path) => _send('DELETE', path);

  static Future<bool> probe(String host,
      {Duration timeout = const Duration(milliseconds: 600)}) async {
    try {
      final res = await http
          .get(Uri.parse('http://$host:${Device.port}/api/health'))
          .timeout(timeout);
      if (res.statusCode != 200) return false;
      final json = jsonDecode(res.body);
      return json is Map && json['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  Future<String> login(String password) async {
    final res = await _post('/login', {'password': password});
    return (res as Map)['token'].toString();
  }

  Future<List<Game>> getGames() async {
    final res = await _get('/games');
    return (res as List).map((e) => Game.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<NowPlaying> getNowPlaying() async {
    final res = await _get('/games/playing/current', timeout: const Duration(seconds: 8));
    return NowPlaying.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<void> startGame(String id) => _post('/games/$id/start');
  Future<void> stopGame() => _post('/games/playing/stop');
  Future<void> renameGame(String id, String name) => _put('/games/$id', {'name': name});
  Future<void> deleteGame(String id) => _delete('/games/$id');
  Future<void> setGameCore(String id, String core) => _put('/games/$id/core', {'core': core});

  Future<List<GameCore>> getGameCores(String id) async {
    final res = await _get('/games/$id/cores');
    return (res as List).map((e) => GameCore.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  String coverUrl(String id) => '$_base/games/$id/cover';

  Future<List<CoverCandidate>> lookupCovers(String id) async {
    final res = await _get('/games/$id/lookup-covers', timeout: const Duration(seconds: 25));
    final covers = (res as Map)['covers'] as List? ?? [];
    return covers.map((e) => CoverCandidate.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<void> setCoverFromUrl(String id, String url) =>
      _post('/games/$id/cover-from-url', {'coverUrl': url});

  Future<void> uploadGame(Uint8List bytes, String fieldFileName, {String? name}) async {
    final req = http.MultipartRequest('POST', _uri('/games'))
      ..headers.addAll(_authHeaders)
      ..files.add(http.MultipartFile.fromBytes('rom', bytes, filename: fieldFileName));
    if (name != null && name.isNotEmpty) req.fields['name'] = name;
    await _sendMultipart(req);
  }

  Future<void> uploadCover(String id, Uint8List bytes, String filename) async {
    final req = http.MultipartRequest('POST', _uri('/games/$id/cover'))
      ..headers.addAll(_authHeaders)
      ..files.add(http.MultipartFile.fromBytes('cover', bytes, filename: filename));
    await _sendMultipart(req);
  }

  Future<void> _sendMultipart(http.MultipartRequest req) async {
    final streamed = await _http.send(req).timeout(const Duration(minutes: 5));
    final res = await http.Response.fromStream(streamed);
    _decode(res);
  }

  Future<List<AppItem>> getApps() async {
    final res = await _get('/apps');
    return (res as List).map((e) => AppItem.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<void> createApp(Map<String, dynamic> body) => _post('/apps', body);
  Future<void> updateApp(String id, Map<String, dynamic> body) => _put('/apps/$id', body);
  Future<void> deleteApp(String id) => _delete('/apps/$id');
  Future<void> launchApp(String id) => _post('/apps/$id/launch');
  Future<void> reorderApps(List<String> ids) => _post('/apps/reorder', {'order': ids});

  String appIconUrl(String id) => '$_base/apps/$id/icon';

  Future<void> uploadAppIcon(String id, Uint8List bytes, String filename) async {
    final req = http.MultipartRequest('POST', _uri('/apps/$id/icon'))
      ..headers.addAll(_authHeaders)
      ..files.add(http.MultipartFile.fromBytes('icon', bytes, filename: filename));
    await _sendMultipart(req);
  }

  Future<List<GameList>> getLists() async {
    final res = await _get('/lists');
    return (res as List).map((e) => GameList.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<GameList?> getSelectedList() async {
    try {
      final res = await _get('/lists/selected');
      return GameList.fromJson((res as Map).cast<String, dynamic>());
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> setSelectedList(String id) => _post('/lists/selected', {'listId': id});
  Future<void> createList(String name, String type) =>
      _post('/lists', {'name': name, 'type': type});
  Future<void> renameList(String id, String name) => _put('/lists/$id', {'name': name});
  Future<void> deleteList(String id) => _delete('/lists/$id');

  Future<List<String>> getListGameIds(String id) async {
    final res = await _get('/lists/$id/games');
    return ((res as Map)['gameIds'] as List? ?? []).map((e) => e.toString()).toList();
  }

  Future<void> setListGames(String id, List<String> gameIds) =>
      _put('/lists/$id/games', {'gameIds': gameIds});

  Future<List<SaveFolder>> getSaveFolders() async {
    final res = await _get('/save-folders');
    return (res as List).map((e) => SaveFolder.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<void> createSaveFolder(String name) => _post('/save-folders', {'name': name});
  Future<void> renameSaveFolder(String uuid, String name) =>
      _put('/save-folders/$uuid', {'name': name});
  Future<void> deleteSaveFolder(String uuid) => _delete('/save-folders/$uuid');
  Future<void> activateSaveFolder(String uuid) => _post('/save-folders/$uuid/activate');
  Future<void> lockSaveFolder(String uuid) => _post('/save-folders/$uuid/lock');
  Future<void> unlockSaveFolder(String uuid) => _post('/save-folders/$uuid/unlock');
  Future<void> clearSaveFolder(String uuid) => _post('/save-folders/$uuid/clear');

  Future<List<GameSave>> getSaveFolderGames(String uuid) async {
    final res = await _get('/save-folders/$uuid/games');
    return (res as List).map((e) => GameSave.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<void> deleteGameSaves(String uuid, String gameId) =>
      _delete('/save-folders/$uuid/games/$gameId');

  Future<CoinStatus> getCoinStatus() async {
    final res = await _get('/coin/status', timeout: const Duration(seconds: 6));
    return CoinStatus.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<AppConfig> getConfig() async {
    final res = await _get('/config');
    return AppConfig.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<void> updateConfig(AppConfig config) => _put('/config', config.toUpdateJson());

  Future<String> updatePassword(String newPassword) async {
    final res = await _put('/config/password', {'newPassword': newPassword});
    return (res as Map)['token'].toString();
  }

  Uri terminalWsUri() => Uri.parse(
      'ws://${device.host}:${Device.port}/api/terminal/ws?token=${Uri.encodeComponent(device.token ?? '')}');
  Uri logsWsUri() => Uri.parse(
      'ws://${device.host}:${Device.port}/api/terminal/logs?token=${Uri.encodeComponent(device.token ?? '')}');

  void dispose() => _http.close();
}
