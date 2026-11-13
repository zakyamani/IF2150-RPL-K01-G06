import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app_services.dart';

class PrivatePhoto extends StatefulWidget {
  final AppServices services;
  final String id;
  final double height;
  const PrivatePhoto({
    super.key,
    required this.services,
    required this.id,
    this.height = 180,
  });
  @override
  State<PrivatePhoto> createState() => _PrivatePhotoState();
}

class _PrivatePhotoState extends State<PrivatePhoto> {
  Uint8List? bytes;
  String? error;
  bool loading = true;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant PrivatePhoto old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) load();
  }

  Future<void> load() async {
    final version = ++generation;
    setState(() => loading = true);
    try {
      final value = await widget.services.api.bytes('/media/${widget.id}');
      if (mounted && version == generation) {
        setState(() {
          bytes = value;
          error = null;
        });
      }
    } catch (_) {
      if (mounted && version == generation) {
        setState(() => error = 'Foto belum tersedia.');
      }
    } finally {
      if (mounted && version == generation) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: bytes != null
        ? Image.memory(
            bytes!,
            height: widget.height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const Text('Foto tidak dapat ditampilkan.'),
          )
        : SizedBox(
            height: widget.height,
            child: Center(
              child: loading
                  ? const CircularProgressIndicator()
                  : TextButton.icon(
                      onPressed: load,
                      icon: const Icon(Icons.refresh),
                      label: Text(error!),
                    ),
            ),
          ),
  );
}
