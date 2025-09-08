Amaç: Firebase ile giriş yapan kullanıcıların notlarını offline-first (Isar) saklamak ve Flask API ile senkronize etmek. Riverpod ile durum yönetimi, Dio ile ağ katmanı, Material 3 arayüz.

Hızlı Başlangıç
flutter pub get
dart run build_runner build -d   # Isar codegen
flutter run                      # Android/iOS/WEB


Firebase: firebase_options.dart mevcut. Gerekirse flutterfire configure ile yeniden oluştur.

Backend: Flask API’yi http://127.0.0.1:8000 (Android emülatör: http://10.0.2.2:8000) adresinde çalıştır.

Mimari Özet

Kimlik Doğrulama: firebase_auth (ID Token)

Ağ Katmanı: dio + interceptor (her isteğe Bearer ekler, 401’de token’ı yenileyip tekrar dener)

Durum Yönetimi: flutter_riverpod (AsyncNotifier)

Veri: Isar (lokal db). Offline-first: önce lokalde kaydet, arka planda push/pull.

UI: Material 3, SliverAppBar.large, SearchBar, Drawer.

Klasör Yapısı (özet + ne işe yarar)
lib/
├─ core/
│  ├─ base/view/base_view.dart             # Ortak sayfa iskeleti (varsa)
│  ├─ constants/app/                       # Uygulama sabitleri
│  ├─ enum/app_theme_enum.dart             # Tema enum
│  ├─ init/cache/locale_manager.dart       # Yerel ayar/locale yönetimi
│  ├─ lang/language_manager.dart           # Dil yönetimi (varsa)
│  ├─ navigation/navigation_manager.dart   # Route/Navigation yardımcıları
│  ├─ network/network_manager.dart         # Dio provider + token interceptor (+401 retry)
│  └─ theme/                               # Tema (light/dark) + notifier
│
├─ model/
│  ├─ note_local.dart                      # Isar model (Not)
│  └─ note_local.g.dart                    # (Codegen) -- build_runner üretir
│
├─ viewmodel/
│  ├─ notes_db.dart                        # Notes API istemcisi (Dio çağrıları)
│  ├─ notes_notifier.dart                  # Riverpod kontrolcüsü (create/update/delete/refresh)
│  └─ notes_viewmodel.dart                 # Repository/iş kuralları (offline-first + sync)
│
└─ view/
   ├─ login_screen.dart                    # Firebase oturum açma
   └─ notes_screen.dart                    # Notlar ekranı (Material 3 + Drawer + Search)


Base URL’yi core/network/network_manager.dart içindeki baseUrlProvider’dan değiştir.
Android emülatör → http://10.0.2.2:8000, iOS/sim/masaüstü → http://127.0.0.1:8000.
Fiziksel cihaz → http://<PC_IP>:8000.

Kullanım Akışı

Giriş: Firebase ile oturum aç.

Liste: Notlar yerelden (Isar) yüklenir; ağ varsa otomatik push → pull yapılır.

Oluştur/Düzenle/Sil: Anında lokalde güncellenir, arka planda API’ye gönderilir.

Arama: AppBar altındaki SearchBar ile lokal filtre.

Senkron: AppBar’daki sync ikonu veya pull-to-refresh.

Drawer: Profil görüntüle, çıkış yap.

Önemli Dosyalar

network_manager.dart

Tek Dio kaynağı (Provider).

Her isteğe ID Token ekler.

401 gelirse token’ı getIdToken(true) ile yeniler ve tek sefer retry eder.

notes_viewmodel.dart (Repository)

loadLocal() → sadece aktif kullanıcının notlarını getirir.

push() → aktif kullanıcının kirli kayıtlarını API’ye yollar.

pull() → API’den çek, LWW (last-write-wins) ile lokali güncelle.

(Opsiyonel) purgeOtherUsers() → kullanıcı değişince diğer kullanıcıların lokal kayıtlarını sil.

notes_notifier.dart

build() sırasında Isar’ı açar, bağlantı varsa ilk sync’i bekler (eski notlar gelir).

createNote/updateNote/deleteNote/refreshSync aksiyonları.

notes_screen.dart

Material 3, SliverAppBar.large, SearchBar, kart liste, bottom sheet form.

Drawer: Profil + Çıkış.

Gereksinimler

Flutter 3.22+ / Dart 3.5+

Android için Java 17 (AGP 7.4.2 / Gradle 7.6.1 önerisi)

isar 3.1.x → build_runner şart:

dart run build_runner build -d

Sık Karşılaşılan Sorunlar

Notlar gelmiyor / 401

Backend çalışıyor mu? Base URL doğru mu?

Yalnızca NetworkManager.dioProvider’dan alınan Dio kullanılıyor mu?

Oturum açık mı? Gerekirse yeniden giriş yap.

Farklı hesapla girişte eski notlar görünüyor

Repository kullanıcıya göre filtreliyor.

purgeOtherUsers() aktifleştirildiğinde kullanıcı değişiminde lokal veri temizlenir.

Isar codegen hatası

dart run build_runner build -d

Şema değiştiyse app’i kapatıp yeniden çalıştır.

Android’de backend’e bağlanamıyor

Emülatör: 10.0.2.2

Fiziksel cihaz: bilgisayar IP’si + güvenlik duvarı izni.

Derleme
flutter build apk --release
# veya
flutter build appbundle --release

Notlar

Tema Material 3: useMaterial3: true + colorSchemeSeed ile özelleştirildi.

Web’de test ediyorsan Flask’ta CORS’u aç (origin’ini ekle).

Kod stili: analysis_options.yaml (Flutter lints).

Hepsi bu.
Base URL/tema/çeviri/rota gibi proje sabitlerini core/* altında merkezi yönetecek şekilde ayrıştırdık. Gerekirse “Ayarlar” sayfasını Drawer’dan bağlayıp genişletebilirsin.