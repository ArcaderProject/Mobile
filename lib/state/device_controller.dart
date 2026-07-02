import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/coin_status.dart';
import '../models/device.dart';
import '../models/game.dart';
import '../services/api_client.dart';
import 'device_store.dart';

class DeviceController extends ChangeNotifier {
  final Device device;
  final DeviceStore store;
  late final ApiClient api;

  NowPlaying nowPlaying = NowPlaying.idle();
  CoinStatus? coinStatus;
  bool reachable = true;

  Timer? _pollTimer;
  bool _disposed = false;

  DeviceController(this.device, this.store) {
    api = ApiClient(device);
  }

  void startPolling() {
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final playing = await api.getNowPlaying();
      final coin = await api.getCoinStatus();
      if (_disposed) return;
      nowPlaying = playing;
      coinStatus = coin;
      reachable = true;
      notifyListeners();
    } catch (_) {
      if (_disposed) return;
      if (reachable) {
        reachable = false;
        notifyListeners();
      }
    }
  }

  Future<void> stopGame() async {
    await api.stopGame();
    await _poll();
  }

  Future<void> startGame(String id) async {
    await api.startGame(id);
    await _poll();
  }

  Future<void> updateToken(String token) async {
    device.token = token;
    await store.update(device);
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    api.dispose();
    super.dispose();
  }
}
