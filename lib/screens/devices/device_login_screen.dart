import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

class DeviceLoginScreen extends StatefulWidget {
  final Device device;
  const DeviceLoginScreen({super.key, required this.device});

  @override
  State<DeviceLoginScreen> createState() => _DeviceLoginScreenState();
}

class _DeviceLoginScreenState extends State<DeviceLoginScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_password.text.isEmpty) return;
    setState(() => _busy = true);
    final api = ApiClient(widget.device);
    try {
      final token = await api.login(_password.text);
      if (mounted) Navigator.pop(context, token);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } finally {
      api.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.device.name)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: context.colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_outline,
                      size: 44, color: context.colors.onPrimaryContainer),
                ),
                const SizedBox(height: 24),
                Text('Connect', style: context.text.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  widget.device.host,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  autofocus: true,
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'Admin password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _login,
                    child: _busy
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Unlock'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
