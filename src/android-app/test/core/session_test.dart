import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/core/storage/session_store.dart';

import '../helpers/memory_store.dart';
import '../helpers/samples.dart';

void main() {
  test(
    'logout during a secure write cannot resurrect the old session',
    () async {
      final storage = BlockingStore();
      final store = SessionStore(
        storage,
        initialOrigin: 'https://first.example.test',
      );
      await store.save(SessionBundle.fromJson(sessionJson()));
      storage.block = true;
      final writing = store
          .save(SessionBundle.fromJson(sessionJson()))
          .then<Object?>((_) => null, onError: (Object e) => e);
      await storage.started.future;
      final changing = store.changeOrigin('https://second.example.test');
      storage.release.complete();
      await Future.wait([writing, changing]);
      expect(store.session, isNull);
      expect(store.origin, 'https://second.example.test');
      expect(
        storage.values.keys.where((k) => k.startsWith('private.')),
        isEmpty,
      );
    },
  );
  test(
    'failed secure persistence never leaves an authenticated in-memory session',
    () async {
      final store = SessionStore(
        FailingStore(),
        initialOrigin: 'https://api.example.test',
      );
      await expectLater(
        store.save(SessionBundle.fromJson(sessionJson())),
        throwsStateError,
      );
      expect(store.session, isNull);
    },
  );
  test(
    'changing origin clears private data and invalidates request scope',
    () async {
      final storage = MemoryStore();
      final store = SessionStore(
        storage,
        initialOrigin: 'https://first.example.test',
      );
      await store.save(SessionBundle.fromJson(sessionJson()));
      await storage.write('private.ticket.A', 'private-credential');
      final epoch = store.epoch;
      await store.changeOrigin('https://second.example.test/api/v1');
      expect(store.origin, 'https://second.example.test');
      expect(store.session, isNull);
      expect(store.epoch, greaterThan(epoch));
      expect(
        (await storage.readAll()).keys.where((k) => k.startsWith('private.')),
        isEmpty,
      );
    },
  );
  test(
    'corrupted saved session recovers safely and production rejects HTTP',
    () async {
      final storage = MemoryStore();
      await storage.write('private.session', '{broken');
      await storage.write('private.ticket.A', 'secret');
      final store = SessionStore(
        storage,
        initialOrigin: 'https://api.example.test',
        allowHttp: false,
      );
      await store.restore();
      expect(store.session, isNull);
      expect(
        storage.values.keys.where((k) => k.startsWith('private.')),
        isEmpty,
      );
      await expectLater(
        store.changeOrigin('http://10.0.2.2:3100'),
        throwsFormatException,
      );
    },
  );
}

class FailingStore extends MemoryStore {
  @override
  Future<void> write(String key, String value) async {
    if (key == 'private.session') {
      throw StateError('Secure storage unavailable');
    }
    await super.write(key, value);
  }
}

class BlockingStore extends MemoryStore {
  bool block = false;
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> write(String key, String value) async {
    if (block && key == 'private.session') {
      block = false;
      started.complete();
      await release.future;
    }
    await super.write(key, value);
  }
}
