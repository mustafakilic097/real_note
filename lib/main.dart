import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ConsumerWidget, ProviderScope, WidgetRef;
import 'package:get/get.dart' show GetMaterialApp;
import 'package:real_note/firebase_options.dart';
import 'package:real_note/view/login_screen.dart';
import 'package:real_note/view/notes_screen.dart';
import 'core/init/cache/locale_manager.dart';
import 'core/init/lang/language_manager.dart';
import 'core/init/navigation/navigation_manager.dart';
import 'core/init/theme/theme_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleManager.preferencesInit();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeNotifier themeNotifier = ref.watch(themeNotifierProvider);
    final langInstance = LanguageManager.instance;
    return GetMaterialApp(
      translations: langInstance,
      locale: LocaleManager.instance.getStringValue("locale") == "en" ? langInstance.enLocale : langInstance.trLocale,
      fallbackLocale: langInstance.trLocale,
      theme: themeNotifier.currentTheme,
      title: "Real Notes",
      initialRoute: NavigationManager.getHomeRoute,
      getPages: NavigationManager.routes,
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
        if (snap.hasData) return const NotesPage();
          return const LoginScreen();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
