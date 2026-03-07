import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'package:sofi_test_connect/presentation/splash/splash_page.dart';
import 'package:sofi_test_connect/services/performance_service.dart';
import 'package:sofi_test_connect/services/remote_debug_logger.dart';
import 'package:sofi_test_connect/services/user_preferences_service.dart';
import 'package:sofi_test_connect/utils/web_history_fix.dart';

Future<void> main() async {
  // Web history workaround (only needed for web preview in Dreamflow)
  if (kIsWeb) {
    try {
      installWebHistoryWorkaround();
    } catch (e) {
      debugPrint('[WebHistoryFix] early install failed: $e');
    }
  }

  // Keep bindings and runApp in the SAME (root) zone to avoid web mismatch
  BindingBase.debugZoneErrorsAreFatal = true;
  WidgetsFlutterBinding.ensureInitialized();

  // iOS / mobile optimizations
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  // Firebase init
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[Firebase] initializeApp OK');
  } catch (e, st) {
    debugPrint('[Firebase] initializeApp failed: $e');
    debugPrint('Stack: $st');
  }

  // Web history workaround again (idempotent) to be safe after init.
  if (kIsWeb) {
    try {
      installWebHistoryWorkaround();
    } catch (e) {
      debugPrint('[WebHistoryFix] install (post-init) failed: $e');
    }
  }

  // Helpful: print which Firebase project this build is actually using
  try {
    final app = Firebase.app();
    debugPrint(
        '[Firebase] app="${app.name}" projectId="${app.options.projectId}"');
  } catch (e) {
    debugPrint('[Firebase] Failed to read app/options: $e');
  }

  // Initialize remote debug logger (non-fatal)
  try {
    await RemoteDebugLogger.instance.initialize();
    debugPrint('[RemoteDebugLogger] initialized');
  } catch (e, st) {
    debugPrint('[RemoteDebugLogger] init failed: $e');
    debugPrint('Stack: $st');
  }

  // Initialize performance service
  try {
    await PerformanceService.instance.initialize();
    debugPrint(
      '[PerformanceService] initialized, performanceMode=${PerformanceService.instance.performanceMode}',
    );
  } catch (e) {
    debugPrint('[PerformanceService] init failed: $e');
  }

  // Initialize user preferences
  try {
    await UserPreferencesService.instance.initialize();
    debugPrint('[UserPreferencesService] initialized');
  } catch (e) {
    debugPrint('[UserPreferencesService] init failed: $e');
  }

  // Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🛑 FLUTTER ERROR: ${details.exceptionAsString()}');
    debugPrint('Stack: ${details.stack}');
    FlutterError.presentError(details);

    try {
      RemoteDebugLogger.instance
          .logFatal(
            'Flutter Error: ${details.exceptionAsString()}',
            details.exception,
            details.stack,
          )
          .timeout(const Duration(seconds: 2))
          .catchError((Object err) {
        debugPrint('⚠️ Remote log failed: $err');
      });
    } catch (err) {
      debugPrint('⚠️ Remote log exception: $err');
    }
  };

  // Non-framework errors (platform dispatcher)
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('🛑 PLATFORM ERROR: $error');
    debugPrint('Stack: $stack');

    try {
      RemoteDebugLogger.instance
          .logFatal('PlatformDispatcher Error', error, stack)
          .timeout(const Duration(seconds: 2))
          .catchError((Object err) {
        debugPrint('⚠️ Remote log failed: $err');
      });
    } catch (err) {
      debugPrint('⚠️ Remote log exception: $err');
    }

    return true;
  };

  runApp(const SofiSaintApp());
}

class SofiSaintApp extends StatelessWidget {
  const SofiSaintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sofi Saint',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: Colors.purple,
          secondary: Colors.purpleAccent,
          surface: Colors.grey[900]!,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
          },
        ),
      ),
      home: const SplashPage(),
      scrollBehavior: const _IOSScrollBehavior(),
    );
  }
}

class _IOSScrollBehavior extends ScrollBehavior {
  const _IOSScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}
