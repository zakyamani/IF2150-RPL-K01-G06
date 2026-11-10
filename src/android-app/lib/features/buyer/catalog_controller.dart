import 'package:geolocator/geolocator.dart';

import '../../app_services.dart';
import '../../core/controller.dart';
import '../../core/models/json.dart';
import '../../core/models/offer.dart';

class CatalogController extends Controller {
  final AppServices services;
  final Future<(double, double)> Function() _locate;
  List<Offer> items = [];
  String? cursor, category, locationMessage;
  double? lat, lng;
  int _generation = 0;
  CatalogController(
    this.services, {
    Future<(double, double)> Function()? locate,
  }) : _locate = locate ?? deviceLocation;
  static Future<(double, double)> deviceLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('location disabled');
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      throw StateError('denied');
    }
    final at = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return (at.latitude, at.longitude);
  }

  Future<void> locate() async {
    try {
      final at = await _locate();
      if (disposed) return;
      lat = at.$1;
      lng = at.$2;
      locationMessage = null;
    } catch (_) {
      locationMessage =
          'Lokasi belum tersedia. Katalog tetap bisa dibuka tanpa jarak.';
    }
    if (!disposed) await load();
  }

  Future<bool> load({String? category, bool more = false}) async {
    if (category != null) this.category = category.isEmpty ? null : category;
    final generation = ++_generation;
    return perform(() async {
      final page = await services.api.get(
        '/catalog',
        (j) => Page.fromJson(j, Offer.fromJson),
        query: {
          'limit': 20,
          'category': ?this.category,
          'lat': ?lat,
          'lng': ?lng,
          if (more && cursor != null) 'cursor': cursor,
        },
      );
      if (disposed || generation != _generation) return;
      items = more
          ? [
              ...items,
              ...page.items.where((o) => !items.any((i) => i.id == o.id)),
            ]
          : page.items;
      cursor = page.nextCursor;
    });
  }
}