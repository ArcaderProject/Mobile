import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/device.dart';

class DeviceStore extends ChangeNotifier {
  static const _key = 'arcader_devices';

  final List<Device> _devices = [];
  bool _loaded = false;

  List<Device> get devices => List.unmodifiable(_devices);
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _devices.clear();
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _devices.addAll(
          list.map((e) => Device.fromJson((e as Map).cast<String, dynamic>())),
        );
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_devices.map((d) => d.toJson()).toList()),
    );
  }

  Device? byId(String id) {
    for (final d in _devices) {
      if (d.id == id) return d;
    }
    return null;
  }

  bool hasHost(String host) => _devices.any((d) => d.host == host);

  Future<void> add(Device device) async {
    _devices.add(device);
    await _persist();
    notifyListeners();
  }

  Future<void> update(Device device) async {
    final i = _devices.indexWhere((d) => d.id == device.id);
    if (i >= 0) {
      _devices[i] = device;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    _devices.removeWhere((d) => d.id == id);
    await _persist();
    notifyListeners();
  }
}
