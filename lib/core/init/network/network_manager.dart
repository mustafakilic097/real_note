// ignore: depend_on_referenced_packages
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:real_note/core/constants/app/app_constants.dart';

import '../../model/note_local.dart';

final baseUrlProvider = Provider<String>((ref) {
  // Emülatör: 10.0.2.2  |  iOS sim/web/masaüstü: 127.0.0.1
  if (Platform.isAndroid) return AppConstants.ANDROID_BASE_URL;
  return AppConstants.OTHER_BASE_URL;
});

class NetworkManager {
  NetworkManager._();
  static final instance = NetworkManager._();

  /// Uygulama genelinde tek Dio kaynağı
  final dioProvider = Provider<Dio>((ref) {
    final base = ref.watch(baseUrlProvider);
    final dio = Dio(
      BaseOptions(
        baseUrl: base,
        // 401'de interceptor devreye girsin (500+ yine hata)
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final user = FirebaseAuth.instance.currentUser;
          final idToken = await user?.getIdToken(); // force değil
          if (idToken != null) {
            options.headers['Authorization'] = 'Bearer $idToken';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          // 401 ise tek seferlik zorunlu refresh ve retry
          if (e.response?.statusCode == 401) {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              try {
                final fresh = await user.getIdToken(true); // zorla yenile
                final opts = e.requestOptions;
                opts.headers['Authorization'] = 'Bearer $fresh';
                final retry = await dio.fetch(opts);
                return handler.resolve(retry);
              } catch (_) {
                /* düşerse alttaki handler çalışır */
              }
            }
          }
          handler.next(e);
        },
      ),
    );

    // Debug istersen aç:
    // dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));

    return dio;
  });
}

final isarProvider = FutureProvider<Isar>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  // name vererek eski dosyalarla çatışmayı önlüyoruz (gerekirse v2 yap)
  return Isar.open([NoteLocalSchema], directory: dir.path, name: 'notes_db_v2');
});
