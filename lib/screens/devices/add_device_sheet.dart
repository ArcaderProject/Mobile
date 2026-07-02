import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

String newDeviceId() =>
    'dev_${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';

Future<Device?> showAddDeviceSheet(BuildContext context, {String? initialHost}) {
  return showModalBottomSheet<Device>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddDeviceSheet(initialHost: initialHost),
  );
}

class _AddDeviceSheet extends StatefulWidget {
  final String? initialHost;
  const _AddDeviceSheet({this.initialHost});

  @override
  State<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<_AddDeviceSheet> {
  late final _name = TextEditingController(text: 'Arcader');
  late final _host = TextEditingController(text: widget.initialHost ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final host = _host.text.trim();
    if (host.isEmpty) {
      showToast(context, 'Enter an IP address or hostname', error: true);
      return;
    }
    setState(() => _busy = true);
    final ok = await ApiClient.probe(host, timeout: const Duration(seconds: 4));
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      showToast(context, 'No Arcader machine responded at $host', error: true);
      return;
    }
    Navigator.pop(
      context,
      Device(
        id: newDeviceId(),
        name: _name.text.trim().isEmpty ? 'Arcader' : _name.text.trim(),
        host: host,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add machine', style: context.text.titleLarge),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _host,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
                labelText: 'IP address / host', hintText: '192.168.1.42'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Verify & add'),
            ),
          ),
        ],
      ),
    );
  }
}
