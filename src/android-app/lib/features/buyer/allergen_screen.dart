import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/api/api_error.dart';
import '../../core/models/user.dart';
import '../../core/widgets/action_button.dart';
import '../../core/widgets/formatters.dart';
import '../../core/widgets/screen_helpers.dart';

class AllergenScreen extends StatefulWidget {
  final AppServices services;
  const AllergenScreen({super.key, required this.services});
  @override
  State<AllergenScreen> createState() => _AllergenState();
}

class _AllergenState extends State<AllergenScreen> {
  late final chosen = widget.services.sessions.session!.user.allergenFilters
      .toSet();
  bool busy = false;
  String? error;
  Future<void> save() async {
    setState(() => busy = true);
    try {
      final epoch = widget.services.sessions.epoch;
      final user = await widget.services.api.patch('/auth/allergens', {
        'allergen_filters': chosen.toList(),
      }, User.fromJson);
      final session = widget.services.sessions.session;
      if (session != null) {
        await widget.services.sessions.save(
          session.withUser(user),
          expectedEpoch: epoch,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Filter belum tersimpan. Coba kembali.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hindari alergen')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Notice(allergenDisclaimer, warning: true),
          const Text(
            'Paket yang melaporkan alergen pilihan Anda akan disembunyikan dari katalog.',
          ),
          ...allergenChoices.map(
            (a) => CheckboxListTile(
              title: Text(a),
              value: chosen.contains(a),
              onChanged: busy
                  ? null
                  : (v) =>
                        setState(() => v! ? chosen.add(a) : chosen.remove(a)),
            ),
          ),
          if (error != null) Notice(error!, warning: true),
          ActionButton(label: 'Simpan filter', busy: busy, onPressed: save),
        ],
      ),
    ),
  );
}