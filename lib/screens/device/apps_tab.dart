import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_item.dart';
import '../../services/api_client.dart';
import '../../state/device_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

class AppsTab extends StatefulWidget {
  const AppsTab({super.key});

  @override
  State<AppsTab> createState() => _AppsTabState();
}

class _AppsTabState extends State<AppsTab> {
  List<AppItem>? _apps;
  String? _error;
  String _query = '';

  ApiClient get _api => context.read<DeviceController>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final apps = await _api.getApps();
      if (!mounted) return;
      setState(() {
        _apps = apps;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  List<AppItem> get _filtered {
    final all = _apps ?? [];
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((a) => a.name.toLowerCase().contains(q) || a.type.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _addOrEdit([AppItem? app]) async {
    final saved = await showAppForm(context, _api, app: app);
    if (saved) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _searchBar(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        decoration: const InputDecoration(
          hintText: 'Search apps…',
          prefixIcon: Icon(Icons.search),
          isDense: true,
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load apps',
        subtitle: _error,
        action: OutlinedButton(onPressed: _load, child: const Text('RETRY')),
      );
    }
    if (_apps == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final apps = _filtered;
    if (apps.isEmpty) {
      return EmptyState(
        icon: Icons.apps_outlined,
        title: _query.isEmpty ? 'No apps yet' : 'No matches',
        subtitle: _query.isEmpty ? 'Add a web app or a native program.' : null,
        action: _query.isEmpty
            ? FilledButton.icon(
                onPressed: () => _addOrEdit(),
                icon: const Icon(Icons.add),
                label: const Text('ADD APP'))
            : null,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          childAspectRatio: 0.78,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: apps.length,
        itemBuilder: (_, i) => _AppCard(app: apps[i], api: _api, onChanged: _load),
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  final AppItem app;
  final ApiClient api;
  final VoidCallback onChanged;
  const _AppCard({required this.app, required this.api, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showAppActions(context, api, app, onChanged),
      child: Opacity(
        opacity: app.enabled ? 1 : 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _icon(context),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => showAppActions(context, api, app, onChanged),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.more_vert, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Material(
                        color: context.colors.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => runGuarded(context, () => api.launchApp(app.id),
                              success: 'Launching ${app.name}'),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(Icons.play_arrow, size: 20, color: context.colors.onPrimary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(app.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text(app.isWeb ? 'Web app' : 'App',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _icon(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(app.isWeb ? Icons.language : Icons.terminal,
          size: 40, color: scheme.onSurfaceVariant),
    );
    if (!app.hasIcon) return placeholder;
    return Container(
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(16),
      child: Image.network(
        api.appIconUrl(app.id),
        headers: api.authImageHeaders,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

Future<void> showAppActions(
    BuildContext context, ApiClient api, AppItem app, VoidCallback onChanged) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Launch'),
            onTap: () async {
              Navigator.pop(sheet);
              await runGuarded(context, () => api.launchApp(app.id),
                  success: 'Launching ${app.name}');
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            onTap: () async {
              Navigator.pop(sheet);
              final saved = await showAppForm(context, api, app: app);
              if (saved) onChanged();
            },
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Upload icon'),
            onTap: () async {
              Navigator.pop(sheet);
              final result =
                  await FilePicker.pickFiles(withData: true, type: FileType.image);
              if (result == null || result.files.isEmpty) return;
              final file = result.files.first;
              if (file.bytes == null || !context.mounted) return;
              final ok = await runGuarded(
                  context, () => api.uploadAppIcon(app.id, file.bytes!, file.name),
                  success: 'Icon updated');
              if (ok) onChanged();
            },
          ),
          ListTile(
            leading: Icon(app.enabled ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            title: Text(app.enabled ? 'Disable' : 'Enable'),
            onTap: () async {
              Navigator.pop(sheet);
              final ok = await runGuarded(
                  context, () => api.updateApp(app.id, {'enabled': !app.enabled}),
                  success: app.enabled ? 'Disabled' : 'Enabled');
              if (ok) onChanged();
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: context.colors.error),
            title: Text('Delete', style: TextStyle(color: context.colors.error)),
            onTap: () async {
              Navigator.pop(sheet);
              if (await confirmDialog(context,
                  title: 'Delete app',
                  message: 'Delete "${app.name}"? This cannot be undone.',
                  confirmLabel: 'DELETE')) {
                if (!context.mounted) return;
                final ok = await runGuarded(context, () => api.deleteApp(app.id),
                    success: 'App deleted');
                if (ok) onChanged();
              }
            },
          ),
        ],
      ),
    ),
  );
}

Future<bool> showAppForm(BuildContext context, ApiClient api, {AppItem? app}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _AppForm(api: api, app: app),
    ),
  );
  return result ?? false;
}

class _AppForm extends StatefulWidget {
  final ApiClient api;
  final AppItem? app;
  const _AppForm({required this.api, this.app});

  @override
  State<_AppForm> createState() => _AppFormState();
}

class _AppFormState extends State<_AppForm> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _userAgent;
  late final TextEditingController _exec;
  late final TextEditingController _args;
  String _type = 'web';
  bool _enabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.app;
    _name = TextEditingController(text: a?.name ?? '');
    _url = TextEditingController(text: a?.url ?? '');
    _userAgent = TextEditingController(text: a?.userAgent ?? '');
    _exec = TextEditingController(text: a?.exec ?? '');
    _args = TextEditingController(text: (a?.args ?? const []).join(' '));
    _type = a?.type ?? 'web';
    _enabled = a?.enabled ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _userAgent.dispose();
    _exec.dispose();
    _args.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (_type == 'web' ? _url.text.trim().isNotEmpty : _exec.text.trim().isNotEmpty);

  Future<void> _save() async {
    if (!_valid) return;
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'type': _type,
      'enabled': _enabled,
    };
    if (_type == 'web') {
      body['url'] = _url.text.trim();
      body['userAgent'] = _userAgent.text.trim().isEmpty ? null : _userAgent.text.trim();
      body['exec'] = null;
      body['args'] = <String>[];
    } else {
      body['exec'] = _exec.text.trim();
      body['args'] = _args.text.trim().isEmpty ? <String>[] : _args.text.trim().split(RegExp(r'\s+'));
      body['url'] = null;
      body['userAgent'] = null;
    }
    final ok = await runGuarded(
      context,
      () => widget.app == null ? widget.api.createApp(body) : widget.api.updateApp(widget.app!.id, body),
      success: widget.app == null ? 'App added' : 'App updated',
    );
    if (mounted) setState(() => _saving = false);
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.app == null ? 'Add app' : 'Edit app',
              style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'Jellyfin'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'web', label: Text('Web'), icon: Icon(Icons.language)),
              ButtonSegment(value: 'native', label: Text('Native'), icon: Icon(Icons.terminal)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          if (_type == 'web') ...[
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                  labelText: 'URL', hintText: 'https://jellyfin.example/tv'),
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _userAgent,
              decoration: const InputDecoration(labelText: 'User agent (optional)'),
            ),
          ] else ...[
            TextField(
              controller: _exec,
              decoration: const InputDecoration(
                  labelText: 'Executable', hintText: '/usr/bin/nautilus'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _args,
              decoration: const InputDecoration(
                  labelText: 'Arguments (space-separated)', hintText: '--new-window'),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: (!_valid || _saving) ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
