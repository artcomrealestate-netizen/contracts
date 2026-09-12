import 'package:firebase_core/firebase_core.dart';

import 'firebase_options_dev.dart' as dev;
import 'firebase_options_staging.dart' as staging;
import 'firebase_options_prod.dart' as prod;

enum AppEnvironment { dev, staging, prod }

/// Selects the Firebase project for the contract-system module at build time
/// via `--dart-define=APP_ENV=dev|staging|prod` (defaults to `dev`), mirroring
/// the existing `--dart-define=use_arabic=...` convention used for PDF text
/// shaping (see lib/pdf/quotation_pdf_builder.dart). No native build flavors
/// are used so the existing Android/iOS signing and release pipeline is
/// untouched.
class Environment {
  static const String _raw = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static AppEnvironment get current {
    switch (_raw) {
      case 'staging':
        return AppEnvironment.staging;
      case 'prod':
        return AppEnvironment.prod;
      case 'dev':
      default:
        return AppEnvironment.dev;
    }
  }

  static FirebaseOptions get firebaseOptions {
    switch (current) {
      case AppEnvironment.dev:
        return dev.DefaultFirebaseOptions.currentPlatform;
      case AppEnvironment.staging:
        return staging.DefaultFirebaseOptions.currentPlatform;
      case AppEnvironment.prod:
        return prod.DefaultFirebaseOptions.currentPlatform;
    }
  }
}
