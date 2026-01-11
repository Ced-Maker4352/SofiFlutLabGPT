import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'package:sofi_test_connect/presentation/splash/splash_page.dart';
import 'package:sofi_test_connect/services/remote_debug_logger.dart';
import 'package:sofi_test_connect/services/performance_service.dart';
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

  // iOS-specific optimizations
  if (!kIsWeb) {
    // Lock orientation to portrait for consistent UX on iPhone
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Set iOS status bar style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  // Load environment variables
  try {
    await dotenv.load(fileName: "assets/.env");
    debugPrint('[dotenv] Loaded assets/.env');
  } catch (e, st) {
    // Do not crash the app if .env is missing; continue with defaults
    debugPrint('[dotenv] Skipping .env load (optional). Error: $e');
    debugPrint('[dotenv] Stack: $st');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[Firebase] initializeApp OK');
  } catch (e, st) {
    // Surface the error but don’t abort; UI can still render and features may degrade
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
    debugPrint('[Firebase] app="${app.name}" projectId="${app.options.projectId}"');
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
  
  // Initialize performance service (loads saved settings for iOS stability)
  try {
    await PerformanceService.instance.initialize();
    debugPrint('[PerformanceService] initialized, performanceMode=${PerformanceService.instance.performanceMode}');
  } catch (e) {
    debugPrint('[PerformanceService] init failed: $e');
  }

  // Set up Flutter error handler with guaranteed logging
  FlutterError.onError = (FlutterErrorDetails details) {
    // Always print locally first
    debugPrint('🛑 FLUTTER ERROR: ${details.exceptionAsString()}');
    debugPrint('Stack: ${details.stack}');
    FlutterError.presentError(details);
    
    // Try to log remotely, but don't let it block or fail
    try {
      RemoteDebugLogger.instance.logFatal(
        'Flutter Error: ${details.exceptionAsString()}',
        details.exception,
        details.stack,
      ).timeout(const Duration(seconds: 2)).catchError((e) {
        debugPrint('⚠️ Remote log failed: $e');
      });
    } catch (e) {
      debugPrint('⚠️ Remote log exception: $e');
    }
  };

  // Catch framework-independent errors (PlatformDispatcher)
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('🛑 PLATFORM ERROR: $error');
    debugPrint('Stack: $stack');
    try {
      RemoteDebugLogger.instance.logFatal('PlatformDispatcher Error', error, stack)
        .timeout(const Duration(seconds: 2))
        .catchError((e) => debugPrint('⚠️ Remote log failed: $e'));
    } catch (e) {
      debugPrint('⚠️ Remote log exception: $e');
    }
    return true; // prevents default crash logging from duplicating
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
        // iOS-friendly styling
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        // Cupertino-style page transitions on iOS
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
          },
        ),
      ),
      home: const SplashPage(),
      // Enable iOS-style scroll physics globally
      scrollBehavior: const _IOSScrollBehavior(),
    );
  }
}

/// Custom scroll behavior for iOS-like bouncy physics
class _IOSScrollBehavior extends ScrollBehavior {
  const _IOSScrollBehavior();
  
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}
