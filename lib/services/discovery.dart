import 'dart:async';

import 'package:network_info_plus/network_info_plus.dart';

import 'api_client.dart';

class DiscoveryService {
  Stream<String> scan() async* {
    final controller = StreamController<String>();
    final ip = await _localIp();
    if (ip == null) {
      await controller.close();
      yield* controller.stream;
      return;
    }

    final prefix = ip.substring(0, ip.lastIndexOf('.'));
    const batchSize = 32;

    () async {
      for (var start = 1; start <= 254; start += batchSize) {
        final futures = <Future>[];
        for (var i = start; i < start + batchSize && i <= 254; i++) {
          final host = '$prefix.$i';
          futures.add(ApiClient.probe(host).then((ok) {
            if (ok && !controller.isClosed) controller.add(host);
          }));
        }
        await Future.wait(futures);
      }
      await controller.close();
    }();

    yield* controller.stream;
  }

  Future<String?> _localIp() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      if (ip != null && ip.contains('.') && ip != '0.0.0.0') return ip;
    } catch (_) {}
    return null;
  }
}
