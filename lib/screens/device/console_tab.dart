import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:xterm/xterm.dart';

import '../../services/api_client.dart';
import '../../state/device_controller.dart';
import '../../theme/app_theme.dart';

const _terminalTheme = TerminalTheme(
  cursor: Color(0xFFB9F5C0),
  selection: Color(0x40B9F5C0),
  foreground: Color(0xFFCFF7D4),
  background: Color(0xFF07070C),
  black: Color(0xFF000000),
  red: Color(0xFFCD3131),
  green: Color(0xFF0DBC79),
  yellow: Color(0xFFE5E510),
  blue: Color(0xFF2472C8),
  magenta: Color(0xFFBC3FBC),
  cyan: Color(0xFF11A8CD),
  white: Color(0xFFE5E5E5),
  brightBlack: Color(0xFF666666),
  brightRed: Color(0xFFF14C4C),
  brightGreen: Color(0xFF23D18B),
  brightYellow: Color(0xFFF5F543),
  brightBlue: Color(0xFF3B8EEA),
  brightMagenta: Color(0xFFD670D6),
  brightCyan: Color(0xFF29B8DB),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFFFFFF2B),
  searchHitBackgroundCurrent: Color(0xFF31FF26),
  searchHitForeground: Color(0xFF000000),
);

class ConsoleTab extends StatefulWidget {
  const ConsoleTab({super.key});

  @override
  State<ConsoleTab> createState() => _ConsoleTabState();
}

enum _Mode { terminal, logs }

class _ConsoleTabState extends State<ConsoleTab> {
  _Mode _mode = _Mode.terminal;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  late Terminal _terminal;

  ApiClient get _api => context.read<DeviceController>().api;

  @override
  void initState() {
    super.initState();
    _initTerminal();
    _connect();
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  void _initTerminal() {
    _terminal = Terminal(maxLines: 10000);
    _terminal.onOutput = (data) {
      if (_mode == _Mode.terminal) {
        _channel?.sink.add(Uint8List.fromList(utf8.encode(data)));
      }
    };
    _terminal.onResize = (w, h, pw, ph) {
      if (_mode == _Mode.terminal) {
        _channel?.sink.add(jsonEncode({'type': 'resize', 'cols': w, 'rows': h}));
      }
    };
  }

  void _teardown() {
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _switchMode(_Mode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    _connect();
  }

  void _connect() {
    _teardown();
    setState(_initTerminal);
    final uri = _mode == _Mode.terminal ? _api.terminalWsUri() : _api.logsWsUri();
    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _sub = channel.stream.listen(
        _onData,
        onError: (e) => _terminal.write('\r\n[connection error: $e]\r\n'),
        onDone: () => _terminal.write('\r\n[session closed]\r\n'),
      );
      if (_mode == _Mode.terminal) {
        channel.sink.add(jsonEncode(
            {'type': 'resize', 'cols': _terminal.viewWidth, 'rows': _terminal.viewHeight}));
      }
    } catch (e) {
      _terminal.write('\r\n[could not connect: $e]\r\n');
    }
  }

  void _onData(dynamic data) {
    if (data is String) {
      _terminal.write(data);
    } else if (data is List<int>) {
      _terminal.write(utf8.decode(data, allowMalformed: true));
    } else {
      _terminal.write(data.toString());
    }
  }

  void _send(String seq) {
    if (_channel == null || _mode != _Mode.terminal || seq.isEmpty) return;
    _channel!.sink.add(Uint8List.fromList(utf8.encode(seq)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _toolbar(),
        Expanded(
          child: TerminalView(
            _terminal,
            theme: _terminalTheme,
            padding: const EdgeInsets.all(8),
            readOnly: _mode != _Mode.terminal,
            textStyle: const TerminalStyle(fontSize: 12.5, fontFamily: 'monospace'),
          ),
        ),
        if (_mode == _Mode.terminal) _keyRow(),
      ],
    );
  }

  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.outlineVariant)),
      ),
      child: Row(
        children: [
          SegmentedButton<_Mode>(
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            segments: const [
              ButtonSegment(value: _Mode.terminal, label: Text('Shell'), icon: Icon(Icons.terminal, size: 16)),
              ButtonSegment(value: _Mode.logs, label: Text('Logs'), icon: Icon(Icons.article_outlined, size: 16)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => _switchMode(s.first),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Reconnect',
            visualDensity: VisualDensity.compact,
            onPressed: _connect,
            icon: const Icon(Icons.refresh, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _keyRow() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _keyChip('TAB', '\t'),
              _keyChip('ESC', '\x1b'),
              _keyChip('^C', '\x03'),
              _keyChip('^D', '\x04'),
              _keyChip('^L', '\x0c'),
              _keyChip('↑', '\x1b[A'),
              _keyChip('↓', '\x1b[B'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _keyChip(String label, String seq) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        visualDensity: VisualDensity.compact,
        onPressed: () => _send(seq),
      ),
    );
  }
}
