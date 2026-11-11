import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../app_services.dart';
import '../models/json.dart';
import '../models/notification.dart';

abstract interface class InboxSocket {
  Stream<InboxEvent> get events;
  Stream<bool> get states;
  Future<void> start({String after = '0'});
  void setCursor(String value);
  Future<void> stop();
  Future<void> dispose();
}

class SocketClient implements InboxSocket {
  final AppServices services;
  final Future<WebSocket> Function(String) connect;
  final Duration Function(int) delay;
  final _events = StreamController<InboxEvent>.broadcast(),
      _states = StreamController<bool>.broadcast();
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  bool _active = false;
  int _generation = 0, _attempt = 0;
  String _cursor = '0';
  SocketClient(
    this.services, {
    Future<WebSocket> Function(String)? connect,
    Duration Function(int)? delay,
  }) : connect = connect ?? WebSocket.connect,
       delay =
           delay ??
           ((n) => Duration(
             milliseconds:
                 min(30000, 1000 * (1 << min(n, 5))) + Random().nextInt(501),
           ));
  @override
  Stream<InboxEvent> get events => _events.stream;
  @override
  Stream<bool> get states => _states.stream;
  @override
  void setCursor(String value) {
    _cursor = value;
  }

  @override
  Future<void> start({String after = '0'}) async {
    await stop();
    _active = true;
    _cursor = after;
    _attempt = 0;
    await _open(_generation);
  }

  Future<void> _open(int generation) async {
    if (!_active ||
        generation != _generation ||
        services.sessions.session == null ||
        services.sessions.origin.isEmpty) {
      return;
    }
    final epoch = services.sessions.epoch;
    try {
      final ticket = await services.api.post('/notifications/ws-ticket', {
        'after': _cursor,
      }, (j) => text(j, 'ticket'));
      if (!_active ||
          generation != _generation ||
          epoch != services.sessions.epoch) {
        return;
      }
      final origin = Uri.parse(services.sessions.origin);
      final uri = origin.replace(
        scheme: origin.scheme == 'https' ? 'wss' : 'ws',
        path: '/ws',
        queryParameters: {'ticket': ticket},
      );
      final ws = await connect(uri.toString())
          .timeout(const Duration(seconds: 12));
      if (!_active ||
          generation != _generation ||
          epoch != services.sessions.epoch) {
        await ws.close();
        return;
      }
      _socket = ws;
      ws.pingInterval = const Duration(seconds: 25);
      _attempt = 0;
      _states.add(true);
      _subscription = ws.listen(
        (data) {
          try {
            if (data is! String || data.length > 16384) {
              throw const FormatException();
            }
            final event = InboxEvent.fromJson(jsonObject(jsonDecode(data)));
            _events.add(event);
          } catch (_) {
            ws.close(1003, 'Invalid inbox payload');
          }
        },
        onError: (Object e) => _lost(generation),
        onDone: () => _lost(generation),
        cancelOnError: true,
      );
    } catch (_) {
      _lost(generation);
    }
  }

  void _lost(int generation) {
    if (!_active || generation != _generation || _retry != null) return;
    _states.add(false);
    _retry = Timer(delay(_attempt++), () {
      _retry = null;
      _open(generation);
    });
  }

  @override
  Future<void> stop() async {
    _active = false;
    _generation++;
    _retry?.cancel();
    _retry = null;
    _states.add(false);
    await _subscription?.cancel();
    _subscription = null;
    final ws = _socket;
    _socket = null;
    if (ws != null) {
      unawaited(
        ws.close().timeout(const Duration(seconds: 2)).catchError((_) {
          return null;
        }),
      );
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _events.close();
    await _states.close();
  }
}
