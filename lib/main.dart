import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'core/bindings/initial_binding.dart';
import 'core/constants/app_constants.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/customer_theme.dart';
import 'data/firebase/firebase_bootstrap.dart';

/// Padma Collections — entry point.
///
/// Boots Firebase (degrading to the local demo catalogue when no project is
/// configured), registers dependencies, then hands off to the splash screen,
/// which decides between the customer app and the admin app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-only: the customer app is a shopping experience, and the admin
  // drawer layout is designed for a phone in the hand.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Never block the app on Firebase — a slow network must not strand the
  // customer on a blank screen.
  await FirebaseBootstrap.init();

  runApp(const PadmaApp());
}

/// Root widget.
class PadmaApp extends StatelessWidget {
  const PadmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: CustomerTheme.theme,
      initialBinding: InitialBinding(),
      initialRoute: Routes.splash,
      getPages: AppPages.pages,

      builder: (BuildContext context, Widget? child) {
        // Large accessibility scales break the dense product grids.
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: child ?? const SizedBox.shrink(),
        );
      },

      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 280),
    );
  }
}
