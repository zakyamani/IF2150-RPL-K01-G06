import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../app_services.dart';
import '../../core/controller.dart';
import '../../core/models/notification.dart';
import '../../core/models/user.dart';

abstract interface class MonitorPlatform {
  Future<void> initialize(void Function(Object) callback);
  Future<bool> requestPermission();
  Future<void> start();
  Future<void> stop();
  Future<void> update(String text);
  void send(Map<String, Object?> data);
  void dispose();
}

@pragma('vm:entry-point')
void monitorEntryPoint() {
  FlutterForegroundTask.setTaskHandler(_MonitorTask());
}

class _MonitorTask extends TaskHandler {
  String? actor, resource;
  int? epoch;
  DateTime lastAck = DateTime.now();
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    lastAck = timestamp;
    FlutterForegroundTask.sendDataToMain({'kind': 'probe'});
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (timestamp.difference(lastAck) > const Duration(seconds: 90)) {
      unawaited(FlutterForegroundTask.stopService());
      return;
    }
    FlutterForegroundTask.sendDataToMain({'kind': 'probe'});
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    FlutterForegroundTask.sendDataToMain({
      'kind': 'stopped',
      'timeout': isTimeout,
      'actor': actor,
      'epoch': epoch,
    });
    actor = null;
    resource = null;
    epoch = null;
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      lastAck = DateTime.now();
      actor = data['actor'] as String?;
      epoch = data['epoch'] as int?;
      if (data['resource_id'] is String) {
        resource = data['resource_id'] as String;
      }
      if (data['kind'] == 'clear') {
        actor = null;
        resource = null;
        epoch = null;
      }
    }
  }

  void tap() {
    FlutterForegroundTask.launchApp();
    FlutterForegroundTask.sendDataToMain({
      'kind': 'tap',
      'actor': actor,
      'epoch': epoch,
      'resource_id': resource,
    });
  }

  @override
  void onNotificationPressed() => tap();
  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      unawaited(FlutterForegroundTask.stopService());
    } else {
      tap();
    }
  }
}

class AndroidMonitorPlatform implements MonitorPlatform {
  final bool enabled;
  void Function(Object)? receiver;
  AndroidMonitorPlatform({this.enabled = true});
  @override
  Future<void> initialize(void Function(Object) callback) async {
    if (!enabled || !Platform.isAndroid) return;
    receiver = callback;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(callback);
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sisarasa.orders',
        channelName: 'Pemantau pesanan',
        channelDescription: 'Pemantauan pesanan yang diaktifkan penjual',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(20000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowAutoRestart: false,
        allowWakeLock: true,
        allowWifiLock: false,
        stopWithTask: false,
      ),
    );
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!enabled || !Platform.isAndroid) return false;
    var permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      permission = await FlutterForegroundTask.requestNotificationPermission();
    }
    return permission == NotificationPermission.granted;
  }

  @override
  Future<void> start() async {
    final result = await FlutterForegroundTask.startService(
      serviceId: 235,
      serviceTypes: [ForegroundServiceTypes.dataSync],
      notificationTitle: 'SisaRasa · pemantau pesanan',
      notificationText: 'Pemantauan aktif. Ketuk untuk membuka aplikasi.',
      notificationButtons: [
        const NotificationButton(id: 'inbox', text: 'Buka aplikasi'),
        const NotificationButton(id: 'stop', text: 'Hentikan'),
      ],
      callback: monitorEntryPoint,
    );
    if (result is ServiceRequestFailure) {
      throw StateError('Foreground service unavailable');
    }
  }

  @override
  Future<void> stop() async {
    if (enabled && Platform.isAndroid) {
      await FlutterForegroundTask.stopService();
    }
  }

  @override
  Future<void> update(String text) async {
    if (enabled && Platform.isAndroid) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'SisaRasa · pesanan',
        notificationText: text,
      );
    }
  }

  @override
  void send(Map<String, Object?> data) {
    if (enabled && Platform.isAndroid) {
      FlutterForegroundTask.sendDataToTask(data);
    }
  }

  @override
  void dispose() {
    final callback = receiver;
    if (callback != null) {
      FlutterForegroundTask.removeTaskDataCallback(callback);
    }
  }
}

class SellerMonitor extends Controller {
  final AppServices services;
  final MonitorPlatform platform;
  bool active = false, _initialized = false;
  String? _actor;
  int _epoch;
  final _taps = StreamController<String>.broadcast();
  SellerMonitor(this.services, {MonitorPlatform? platform})
    : platform =
          platform ?? AndroidMonitorPlatform(enabled: services.runtimeEnabled),
      _actor = services.sessions.session?.user.id,
      _epoch = services.sessions.epoch {
    services.sessions.addListener(_scopeChanged);
  }
  Stream<String> get taps => _taps.stream;
  Future<void> initialize() async {
    try {
      await platform.initialize(_receive);
      _initialized = true;
    } catch (_) {
      error = 'Pemantauan belum tersedia pada perangkat ini.';
      changed();
    }
  }

  void _scopeChanged() {
    if (_actor == services.sessions.session?.user.id &&
        _epoch == services.sessions.epoch) {
      return;
    }
    _actor = services.sessions.session?.user.id;
    _epoch = services.sessions.epoch;
    unawaited(stop());
  }

  Future<bool> start() async {
    if (!_initialized) await initialize();
    return perform(() async {
      final actor = services.sessions.session?.user;
      if (actor?.role != Role.seller) throw StateError('Seller required');
      final epoch = services.sessions.epoch;
      if (!await platform.requestPermission()) {
        error = 'izin notifikasi belum diberikan. Inbox dan pesanan tetap dapat digunakan.';
        return;
      }
      if (epoch != services.sessions.epoch ||
          actor?.id != services.sessions.session?.user.id) {
        return;
      }
      await platform.start();
      if (epoch != services.sessions.epoch) {
        await platform.stop();
        return;
      }
      _actor = actor!.id;
      _epoch = epoch;
      active = true;
      _ack();
    }).then((ok) => ok && active);
  }

  void _ack() =>
      platform.send({'kind': 'ack', 'actor': _actor, 'epoch': _epoch});
  void _receive(Object data) {
    if (data is! Map) return;
    if (data['kind'] == 'probe') {
      if (active) _ack();
    } else if (data['kind'] == 'stopped') {
      if (data['actor'] != null &&
          (data['actor'] != _actor || data['epoch'] != _epoch)) {
        return;
      }
      active = false;
      error = data['timeout'] == true
          ? 'Batas pemantauan Android tercapai. Buka aplikasi untuk mengaktifkan kembali.'
          : null;
      changed();
    } else if (data['kind'] == 'tap') {
      final id = acceptTap(data);
      if (id != null) _taps.add(id);
    }
  }

  String? acceptTap(Map data) {
    if (!active ||
        data['actor'] != services.sessions.session?.user.id ||
        data['epoch'] != services.sessions.epoch ||
        services.sessions.session?.user.role != Role.seller) {
      return null;
    }
    final resource = data['resource_id'];
    if (resource is! String ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(resource)) {
      return null;
    }
    return resource;
  }

  Future<void> publish(InboxEvent event) async {
    if (!active ||
        _actor != services.sessions.session?.user.id ||
        _epoch != services.sessions.epoch) {
      return;
    }
    platform.send({
      'kind': 'event',
      'actor': _actor,
      'epoch': _epoch,
      'resource_id': event.resourceId,
    });
    try {
      await platform.update(event.summary);
    } catch (_) {
      error = 'Notifikasi lokal belum diperbarui. Periksa inbox.';
      changed();
    }
  }

  Future<void> stop() async {
    active = false;
    if (_initialized) {
      platform.send({'kind': 'clear'});
      try {
        await platform.stop();
      } catch (_) {}
    }
    changed();
  }

  @override
  void dispose() {
    if (disposed) return;
    services.sessions.removeListener(_scopeChanged);
    unawaited(stop());
    platform.dispose();
    unawaited(_taps.close());
    super.dispose();
  }
}
