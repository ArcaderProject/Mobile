import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_config.dart';
import '../../services/api_client.dart';
import '../../state/device_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  AppConfig? _config;
  String? _error;
  bool _saving = false;

  final _insert = TextEditingController();
  final _info = TextEditingController();
  final _minutes = TextEditingController();
  final _apiKey = TextEditingController();
  final _newPassword = TextEditingController();

  ApiClient get _api => context.read<DeviceController>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _insert.dispose();
    _info.dispose();
    _minutes.dispose();
    _apiKey.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final config = await _api.getConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _error = null;
        _insert.text = config.insertMessage;
        _info.text = config.infoMessage;
        _minutes.text = config.minutesPerCoin;
        _apiKey.text = config.steamGridDbApiKey;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _save() async {
    final config = _config!;
    config
      ..insertMessage = _insert.text
      ..infoMessage = _info.text
      ..minutesPerCoin = _minutes.text
      ..steamGridDbApiKey = _apiKey.text;
    final controller = context.read<DeviceController>();
    setState(() => _saving = true);
    final ok = await runGuarded(context, () => _api.updateConfig(config), success: 'Settings saved');

    if (ok && mounted && _newPassword.text.trim().isNotEmpty) {
      final changed = await runGuarded(
        context,
        () async {
          final token = await _api.updatePassword(_newPassword.text.trim());
          await controller.updateToken(token);
        },
        success: 'Password updated',
      );
      if (changed) _newPassword.clear();
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _config == null) {
      return EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load settings',
          subtitle: _error,
          action: OutlinedButton(onPressed: _load, child: const Text('RETRY')));
    }
    if (_config == null) return const Center(child: CircularProgressIndicator());
    final config = _config!;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _coinStatusCard(),
            const SizedBox(height: 24),
            const SectionLabel('Coin screen'),
            const SizedBox(height: 12),
            _card([
              _textField(_insert, 'Insert message', 'INSERT COIN'),
              const SizedBox(height: 12),
              _textField(_info, 'Info message', null, maxLines: 2),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Coin slot enabled'),
                subtitle: const Text('Require coins to play'),
                value: config.coinSlotEnabled,
                onChanged: (v) => setState(() => config.coinSlotEnabled = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Time mode'),
                subtitle: const Text('Coins buy play time instead of one play each'),
                value: config.timeModeEnabled,
                onChanged: (v) => setState(() => config.timeModeEnabled = v),
              ),
              if (config.timeModeEnabled)
                _textField(_minutes, 'Minutes per coin', '10',
                    keyboardType: TextInputType.number),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Konami code'),
                subtitle: const Text('↑↑↓↓←→←→BA bypasses the coin screen'),
                value: config.konamiCodeEnabled,
                onChanged: (v) => setState(() => config.konamiCodeEnabled = v),
              ),
            ]),
            const SizedBox(height: 24),
            const SectionLabel('Integrations'),
            const SizedBox(height: 12),
            _card([
              _textField(_apiKey, 'SteamGridDB API key', null, obscure: true),
              const SizedBox(height: 8),
              Text('Used to auto-fetch game cover art.',
                  style: context.text.bodySmall
                      ?.copyWith(color: context.colors.onSurfaceVariant)),
            ]),
            const SizedBox(height: 24),
            SectionLabel('Security', color: context.colors.error),
            const SizedBox(height: 12),
            _card([
              Row(
                children: [
                  Expanded(child: _textField(_newPassword, 'New admin password', 'Leave blank to keep', obscure: true)),
                  IconButton(
                    tooltip: 'Generate',
                    onPressed: _generatePassword,
                    icon: Icon(Icons.casino_outlined, color: context.colors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Changing this re-pairs the app automatically.',
                  style: context.text.bodySmall
                      ?.copyWith(color: context.colors.onSurfaceVariant)),
            ]),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: context.colors.onPrimary))
                  : const Icon(Icons.save_outlined),
              label: const Text('Save settings'),
            ),
          ),
        ),
      ],
    );
  }

  void _generatePassword() {
    const chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    final buf = StringBuffer();
    var seed = now;
    for (var i = 0; i < 16; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      buf.write(chars[seed % chars.length]);
    }
    _newPassword.text = buf.toString();
    Clipboard.setData(ClipboardData(text: buf.toString()));
    showToast(context, 'Generated & copied to clipboard');
  }

  Widget _coinStatusCard() {
    final coin = context.watch<DeviceController>().coinStatus;
    return _card([
      Row(
        children: [
          Icon(Icons.monetization_on_outlined, color: context.semantic.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Coin acceptor',
                style: context.text.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          if (coin != null)
            Text(
              coin.freePlay
                  ? 'Free play'
                  : coin.timeMode
                      ? '${coin.formattedTime} left'
                      : '${coin.credits} credits',
              style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600, color: context.colors.primary),
            ),
        ],
      ),
      if (coin != null) ...[
        const SizedBox(height: 6),
        Text(
          coin.hardwareConnected
              ? 'Coin hardware connected'
              : 'Coin hardware not detected',
          style: context.text.bodyMedium
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ],
    ]);
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _textField(TextEditingController c, String label, String? hint,
      {int maxLines = 1, bool obscure = false, TextInputType? keyboardType}) {
    return TextField(
      controller: c,
      maxLines: obscure ? 1 : maxLines,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}
