import 'package:get/get.dart';
import 'package:real_note/view/login_screen.dart';
import 'package:real_note/view/notes_screen.dart';

class NavigationManager {
  static final NavigationManager _instance = NavigationManager._init();
  static NavigationManager get instance => _instance;
  NavigationManager._init();  

  static String get getHomeRoute => "/";
  static String get getLoginRoute => "/login";

  static List<GetPage> get routes => [
        GetPage(name: getHomeRoute, page: () => const NotesPage(),transition: Transition.size,transitionDuration: const Duration(milliseconds: 200)),
        GetPage(name: getLoginRoute, page: () => const LoginScreen(),transition: Transition.size,transitionDuration: const Duration(milliseconds: 200)),
  ];
}
