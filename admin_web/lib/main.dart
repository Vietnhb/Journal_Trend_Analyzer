import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:web/web.dart' as web;

import 'app.dart';
import 'core/core.dart';
import 'firebase_options.dart';

const _useAuthEmulator = bool.fromEnvironment('USE_AUTH_EMULATOR');
const _appCheckDebug = bool.fromEnvironment('APP_CHECK_DEBUG');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
    if (_useAuthEmulator) {
      await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    }
    if (_appCheckDebug) {
      await FirebaseAppCheck.instance.activate(providerWeb: WebDebugProvider());
    } else if (firebaseAppCheckConfigured) {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaEnterpriseProvider(appCheckSiteKey),
      );
    }
    await initializeDateFormatting('vi_VN');
    _removeBootIndicator();
    runApp(
      JournalAdminApp(
        appCheckEnabled: _appCheckDebug || firebaseAppCheckConfigured,
      ),
    );
  } catch (error) {
    _removeBootIndicator();
    runApp(AdminBootstrapFailure(error: error));
  }
}

void _removeBootIndicator() {
  web.document.getElementById('boot')?.remove();
}
