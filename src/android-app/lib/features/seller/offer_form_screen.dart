import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_services.dart';
import '../../core/models/offer.dart';
import '../../core/widgets/action_button.dart';
import '../../core/widgets/formatters.dart';
import '../../core/widgets/screen_helpers.dart';
import 'offer_form_controller.dart';

class OfferFormScreen extends StatefulWidget {
  final AppServices services;
  final SellerOffer? offer;
  const OfferFormScreen({super.key, required this.services, this.offer});
  @override
  State<OfferFormScreen> createState() => _OfferFormState();
}

class _OfferFormState extends State<OfferFormScreen> {
  late final c = OfferFormController(
    widget.services,
    offerId: widget.offer?.id,
    offer: widget.offer,
  );
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> choose(String field, DateTime current) async {
    final day = await showDatePicker(
      context: context,
      initialDate: current.toLocal(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current.toLocal()),
    );
    if (time == null || !mounted) return;
    final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    setState(() {
      switch (field) {
        case 'pickup_start':
          c.start = at;
        case 'pickup_end':
          c.end = at;
        case 'safe_eat_until':
          c.safe = at;
      }
    });
  }

  Widget number(
    String label,
    String value,
    String field,
    void Function(String) update,
  ) => TextFormField(
    enabled: !c.busy && !c.uncertain,
    initialValue: value,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      errorText: c.fields[field]?.join('\n'),
    ),
    onChanged: update,
  );
  Widget dateField(String label, String field, DateTime value, {Key? key}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              key: key,
              onPressed: c.busy || c.uncertain
                  ? null
                  : () => choose(field, value),
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(dateLabel(value)),
            ),
            if (c.fields[field] != null)
              Text(
                c.fields[field]!.join('\n'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.offer == null ? 'Penawaran baru' : 'Ubah penawaran'),
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Notice(
                'Hanya terbitkan makanan yang masih layak. Anda menentukan batas konsumsi dan alergen sesuai kondisi paket.',
              ),
              DropdownButtonFormField<String>(
                initialValue: c.category,
                isExpanded: true,
                isDense: false,
                itemHeight: null,
                decoration: const InputDecoration(labelText: 'Kategori paket'),
                items: categoryChoices
                    .map(
                      (a) => DropdownMenuItem(
                        value: a,
                        child: Text(categoryLabel(a)),
                      ),
                    )
                    .toList(),
                onChanged: c.busy || c.uncertain
                    ? null
                    : (v) => setState(() => c.category = v!),
              ),
              const SizedBox(height: 16),
              number('Kuota paket', c.quota, 'quota', (v) => c.quota = v),
              const SizedBox(height: 16),
              number(
                'Harga normal (Rp)',
                c.normalPrice,
                'normal_price',
                (v) => c.normalPrice = v,
              ),
              const SizedBox(height: 16),
              number(
                'Harga paket (Rp)',
                c.discountPrice,
                'discount_price',
                (v) => c.discountPrice = v,
              ),
              const SizedBox(height: 12),
              const Text(
                'Harga paket 30–50% dari harga normal (diskon 50–70%).',
              ),
              const SizedBox(height: 20),
              Text(
                'Alergen yang terdapat pada paket',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allergenChoices
                    .map(
                      (a) => FilterChip(
                        label: Text(a),
                        selected: c.allergens.contains(a),
                        onSelected: c.busy || c.uncertain
                            ? null
                            : (v) => setState(
                                () => v
                                    ? c.allergens.add(a)
                                    : c.allergens.remove(a),
                              ),
                      ),
                    )
                    .toList(),
              ),
              dateField(
                'Mulai pengambilan',
                'pickup_start',
                c.start,
                key: const Key('pickup-start'),
              ),
              const Text(
                'Maksimal dua jam dari sekarang. Pilih tanggal dan jam lokal.',
              ),
              dateField('Batas pengambilan', 'pickup_end', c.end),
              dateField('Batas konsumsi', 'safe_eat_until', c.safe),
              CheckboxListTile(
                key: const Key('fitness'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: c.fitness,
                onChanged: c.busy || c.uncertain
                    ? null
                    : (v) => setState(() => c.fitness = v!),
                title: const Text(
                  'Saya memastikan paket masih layak dikonsumsi hingga batas konsumsi di atas.',
                ),
              ),
              if (c.fields['fitness_confirmed'] != null)
                Text(
                  c.fields['fitness_confirmed']!.join('\n'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (c.error != null) Notice(c.error!, warning: true),
              const SizedBox(height: 20),
              ActionButton(
                label: 'Simpan penawaran',
                busy: c.busy,
                onPressed: c.uncertain
                    ? null
                    : () async {
                        FocusScope.of(context).unfocus();
                        if (await c.save() && context.mounted) {
                          Navigator.pop(context, true);
                        }
                      },
              ),
              if (c.uncertain)
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Kembali dan periksa penawaran'),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}
