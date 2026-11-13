import 'package:intl/intl.dart';

String rupiah(int value) => NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
).format(value);
String categoryLabel(String category) => switch (category) {
  'makanan_berat' => 'Makanan berat',
  'roti_kudapan' => 'Roti & kudapan',
  'buah_sayur' => 'Buah & sayur',
  'campuran' => 'Paket campuran',
  _ => category,
};
const allergenChoices = [
  'gluten',
  'telur',
  'susu',
  'kacang',
  'kedelai',
  'ikan',
  'kerang',
  'wijen',
];
const categoryChoices = [
  'makanan_berat',
  'roti_kudapan',
  'buah_sayur',
  'campuran',
];
const allergenDisclaimer =
    'Filter alergen tidak menjamin bebas kontaminasi silang. Berhati-hati jika alergi berat (anafilaksis).';
String dateLabel(DateTime value) {
  final d = value.toLocal();
  const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final offset = d.timeZoneOffset;
  final zone = switch (offset.inMinutes) {
    420 => 'WIB',
    480 => 'WITA',
    540 => 'WIT',
    0 => 'UTC',
    _ =>
      'UTC${offset.isNegative ? '-' : '+'}${offset.inHours.abs().toString().padLeft(2, '0')}:${(offset.inMinutes.abs() % 60).toString().padLeft(2, '0')}',
  };
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} · ${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')} $zone';
}
