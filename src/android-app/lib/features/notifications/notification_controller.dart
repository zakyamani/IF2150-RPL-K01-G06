import 'dart:async';
import 'dart:convert';

import '../../app_services.dart';
import '../../core/controller.dart';
import '../../core/models/json.dart';
import '../../core/models/notification.dart';
import '../../core/api/socket_client.dart';

class NotificationController extends Controller {
  final AppServices services;
  final InboxSocket socket;
  final bool enabled;
  final Map<String, InboxEvent> _items = {};
  final _changes = StreamController<InboxEvent>.broadcast();
  StreamSubscription<InboxEvent>? _messages;
  StreamSubscription<bool>? _states;
  String cursor = '0';
  String? historyCursor, _actor;
  int _epoch;
  bool connected = false, cacheAvailable = true;
  Future<void>? _catching;
  int _generation = 0;
  NotificationController(
    this.services, {
    InboxSocket? socket,
    this.enabled = true,
  }) : socket = socket ?? SocketClient(services),
       _actor = services.sessions.session?.user.id,
       _epoch = services.sessions.epoch {
    services.sessions.addListener(_scopeChanged);
  }
  List<InboxEvent> get items => _items.values.toList()
    ..sort(
      (a, b) => BigInt.parse(b.sequence).compareTo(BigInt.parse(a.sequence)),
    );
  int get unread => _items.values.where((e) => e.readAt == null).length;
  Stream<InboxEvent> get changes => _changes.stream;
  bool _valid(int generation) =>
      !disposed &&
      generation == _generation &&
      _actor == services.sessions.session?.user.id &&
      _epoch == services.sessions.epoch;
  void _scopeChanged() {
    final actor = services.sessions.session?.user.id,
        epoch = services.sessions.epoch;
    if (actor == _actor && epoch == _epoch) return;
    _generation++;
    _actor = actor;
    _epoch = epoch;
    _items.clear();
    cursor = '0';
    historyCursor = null;
    connected = false;
    _catching = null;
    unawaited(socket.stop());
    changed();
    if (enabled && actor != null) unawaited(start());
  }

  Future<void> start() async {
    final actor = services.sessions.session?.user.id;
    if (actor == null) return;
    _actor = actor;
    _epoch = services.sessions.epoch;
    final generation = ++_generation;
    await _messages?.cancel();
    await _states?.cancel();
    _messages = socket.events.listen((event) {
      if (_valid(generation)) {
        _merge([event], announce: true);
        unawaited(_persist(generation));
      }
    });
    _states = socket.states.listen((state) {
      if (_valid(generation)) {
        connected = state;
        changed();
        if (state) unawaited(catchUp());
      }
    });
    try {
      final raw = await services.sessions.storage.read('private.inbox.$actor');
      if (raw != null && _valid(generation)) {
        final j = jsonObject(jsonDecode(raw));
        final cached = Page.fromJson({
          'items': j['items'],
          'next_cursor': null,
        }, InboxEvent.fromJson);
        _merge(cached.items, announce: false);
        final saved = text(j, 'cursor');
        if (BigInt.parse(saved) > BigInt.parse(cursor)) cursor = saved;
      }
    } catch (_) {
      if (_valid(generation)) cacheAvailable = false;
    }
    if (!_valid(generation)) return;
    await catchUp(announce: false);
    await history();
    if (enabled && _valid(generation)) await socket.start(after: cursor);
  }

  void _merge(List<InboxEvent> events, {required bool announce}) {
    for (final event in events) {
      final old = _items[event.id];
      _items[event.id] = old?.readAt != null && event.readAt == null
          ? old!
          : event;
      if (BigInt.parse(event.sequence) > BigInt.parse(cursor)) {
        cursor = event.sequence;
      }
      if (old == null && announce) _changes.add(event);
    }
    socket.setCursor(cursor);
    changed();
  }

  Future<void> catchUp({bool announce = true}) {
    if (_catching != null) return _catching!;
    final generation = _generation;
    late Future<void> pending;
    pending = _catchUp(generation, announce).whenComplete(() {
      if (identical(_catching, pending)) _catching = null;
    });
    _catching = pending;
    return pending;
  }

  Future<void> _catchUp(int generation, bool announce) async {
    if (_actor == null || !_valid(generation)) return;
    var after = cursor;
    try {
      while (_valid(generation)) {
        final result = await services.api.get(
          '/notifications',
          (j) => Page.fromJson(j, InboxEvent.fromJson),
          query: {'after': after, 'limit': 50},
        );
        if (!_valid(generation)) return;
        _merge(result.items, announce: announce);
        if (result.nextCursor == null) break;
        if (result.nextCursor == after) throw const FormatException();
        after = result.nextCursor!;
      }
      error = null;
      await _persist(generation);
    } catch (_) {
      if (_valid(generation)) {
        error = 'Inbox belum tersinkron. Buka kembali saat jaringan tersedia.';
        changed();
      }
    }
  }

  Future<bool> history({bool more = false}) => perform(() async {
    final generation = _generation;
    final page = await services.api.get(
      '/notifications',
      (j) => Page.fromJson(j, InboxEvent.fromJson),
      query: {'cursor': ?more ? historyCursor : null, 'limit': 50},
    );
    if (!_valid(generation)) return;
    _merge(page.items, announce: false);
    historyCursor = page.nextCursor;
    await _persist(generation);
  });
  Future<void> _persist(int generation) async {
    if (_actor == null || !_valid(generation)) return;
    final actor = _actor!,
        snapshot = items.take(50).map((e) => e.toJson()).toList(),
        saved = cursor;
    try {
      await services.sessions.runForUser(
        actor,
        () => services.sessions.storage.write(
          'private.inbox.$actor',
          jsonEncode({'items': snapshot, 'cursor': saved}),
        ),
      );
      if (_valid(generation)) cacheAvailable = true;
    } catch (_) {
      if (_valid(generation)) cacheAvailable = false;
    }
  }

  Future<bool> markRead(InboxEvent event) => perform(() async {
    final j = await services.api.post(
      '/notifications/${event.id}/read',
      {},
      (j) => j,
    );
    final current = _items[event.id];
    if (current != null) {
      _items[event.id] = current.withRead(instant(j, 'read_at'));
      await _persist(_generation);
    }
  });
  Future<void>? _closing;
  Future<void> _close() async {
    await _messages?.cancel();
    await _states?.cancel();
    await socket.dispose();
    await _changes.close();
  }

  Future<void> disposeAsync() {
    dispose();
    return _closing ?? Future.value();
  }

  @override
  void dispose() {
    if (disposed) return;
    services.sessions.removeListener(_scopeChanged);
    super.dispose();
    _closing = _close();
  }
}
