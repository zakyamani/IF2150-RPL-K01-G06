# Android SisaRasa

Panduan lengkap: [../README.md](../README.md).

```bash
flutter pub get --enforce-lockfile
flutter run --dart-define=API_BASE=http://10.0.2.2:3100
```

Backend harus hidup. HTTP hanya untuk debug; release memakai HTTPS, signing privat, backup Android off dan cleartext off. `core/theme/` memuat tema, `core/widgets/` komponen bersama, dan `features/` layar/controller per fitur. Pengaturan server tersembunyi kecuali build operator mengaktifkan `DEVELOPER_SETTINGS=true`.

Native test memakai `TEST_API_BASE` terpisah dari API_BASE produksi. `scripts/native-test.sh` meneruskan nilainya ke Flutter dan Gradle instrumentation, sehingga emulator dapat menguji API repo akademik pada port yang berbeda.
