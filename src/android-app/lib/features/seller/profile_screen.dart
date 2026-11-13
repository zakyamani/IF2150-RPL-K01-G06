import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_services.dart';
import '../../core/controller.dart';
import '../../core/models/user.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/action_button.dart';
import '../../core/widgets/private_photo.dart';
import '../../core/widgets/screen_helpers.dart';
import '../buyer/catalog_controller.dart';
import 'seller_repository.dart';

class ProfileScreen extends StatefulWidget {
  final AppServices services;
  const ProfileScreen({super.key, required this.services});
  @override
  State<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends State<ProfileScreen> {
  final state = Controller();
  late final repo = SellerRepository(widget.services);
  MerchantProfile? profile;
  final name = TextEditingController(),
      address = TextEditingController(),
      lat = TextEditingController(),
      lng = TextEditingController(),
      bank = TextEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    state.dispose();
    for (final c in [name, address, lat, lng, bank]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() => state
      .perform(() async {
        final p = await repo.profile();
        if (state.disposed) return;
        profile = p;
        name.text = p.name;
        address.text = p.address;
        lat.text = p.latitude?.toString() ?? '';
        lng.text = p.longitude?.toString() ?? '';
      })
      .then((_) {});
  Future<void> location() async {
    if (!await confirm(
      context,
      title: 'Gunakan lokasi perangkat?',
      detail: 'Pastikan Anda berada di gerai agar pembeli mendapat perkiraan jarak yang sesuai.',
      action: 'Gunakan lokasi',
    )) {
      return;
    }
    await state.perform(() async {
      final at = await CatalogController.deviceLocation();
      if (state.disposed) return;
      lat.text = at.$1.toString();
      lng.text = at.$2.toString();
    });
  }

  Future<void> photo() async {
    await state.perform(() async {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (image == null || state.disposed) return;
      final id = await repo.upload(await image.readAsBytes(), 'shop');
      final updated = await repo.setPhoto(id);
      if (!state.disposed) profile = updated;
    });
  }

  Future<void> save() async {
    final latitude = double.tryParse(lat.text.replaceAll(',', '.')),
        longitude = double.tryParse(lng.text.replaceAll(',', '.'));
    final fields = <String, List<String>>{};
    if (name.text.trim().length < 2 || name.text.trim().length > 100) {
      fields['shop_name'] = ['Nama gerai 2–100 karakter.'];
    }
    if (address.text.trim().length < 5 || address.text.trim().length > 500) {
      fields['address'] = ['Alamat 5–500 karakter.'];
    }
    if (latitude == null ||
        !latitude.isFinite ||
        latitude < -90 ||
        latitude > 90) {
      fields['latitude'] = ['Latitude antara -90 dan 90.'];
    }
    if (longitude == null ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      fields['longitude'] = ['Longitude antara -180 dan 180.'];
    }
    if (bank.text.isNotEmpty && !RegExp(r'^\d{6,30}$').hasMatch(bank.text)) {
      fields['bank_destination'] = ['Tujuan demo 6–30 digit.'];
    }
    if (fields.isNotEmpty) {
      state.fields = fields;
      state.changed();
      return;
    }
    if (await state.perform(() async {
          profile = await repo.saveProfile({
            'shop_name': name.text.trim(),
            'address': address.text.trim(),
            'latitude': latitude,
            'longitude': longitude,
            if (bank.text.isNotEmpty) 'bank_destination': bank.text,
          });
        }) &&
        mounted) {
      Navigator.pop(context, true);
    }
  }

  Widget field(
    String label,
    String key,
    TextEditingController c, {
    int lines = 1,
    TextInputType? type,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: c,
      maxLines: lines,
      keyboardType: type,
      enabled: !state.busy,
      decoration: InputDecoration(
        labelText: label,
        errorText: state.fields[key]?.join('\n'),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profil gerai')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AsyncContent(
              busy: state.busy && profile == null,
              error: profile == null ? state.error : null,
              onRetry: load,
              child: profile == null
                  ? const SizedBox()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (profile!.photoId != null)
                          PrivatePhoto(
                            services: widget.services,
                            id: profile!.photoId!,
                          ),
                        OutlinedButton.icon(
                          onPressed: state.busy ? null : photo,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Pilih foto gerai'),
                        ),
                        const Notice(
                          'Foto dan alamat lengkap hanya dibuka untuk pembeli setelah pembayaran berhasil.',
                        ),
                        field('Nama gerai', 'shop_name', name),
                        field('Alamat lengkap', 'address', address, lines: 3),
                        OutlinedButton.icon(
                          onPressed: state.busy ? null : location,
                          icon: const Icon(Icons.my_location),
                          label: const Text('Gunakan posisi saat ini'),
                        ),
                        const SizedBox(height: 16),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Sesuaikan lokasi secara manual'),
                          children: [
                            field(
                              'Latitude',
                              'latitude',
                              lat,
                              type: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                            ),
                            field(
                              'Longitude',
                              'longitude',
                              lng,
                              type: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                            ),
                          ],
                        ),
                        const Notice(
                          'Tujuan pencairan SIMULASI. Jangan masukkan rekening nyata. Sistem hanya menyimpan empat digit terakhir.',
                          warning: true,
                        ),
                        if (profile!.bankMasked.isNotEmpty)
                          DetailLine(
                            'Tujuan demo tersimpan',
                            profile!.bankMasked,
                          ),
                        TextField(
                          controller: bank,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Tujuan demo baru (opsional)',
                            errorText: state.fields['bank_destination']?.join(
                              '\n',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (state.error != null)
                          Notice(state.error!, warning: true),
                        ActionButton(
                          label: 'Simpan profil',
                          busy: state.busy,
                          onPressed: save,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
