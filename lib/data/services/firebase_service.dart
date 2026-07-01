import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;
  final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  bool _googleSignInInitialized = false;

  Stream<User?> get authStateChanges => auth.authStateChanges();

  User? get currentUser => auth.currentUser;

  Future<UserCredential> signInWithGoogle() async {
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleSignInInitialized = true;
    }

    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google Sign-In did not return an ID token.');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await auth.signInWithCredential(credential);
    await analytics.setUserId(id: result.user?.uid);
    await analytics.logLogin(loginMethod: 'google');
    return result;
  }

  Future<void> signOut() async {
    await logEvent('logout');
    await auth.signOut();
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleSignInInitialized = true;
    }
    await GoogleSignIn.instance.signOut();
    await analytics.setUserId(id: null);
  }

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    try {
      await analytics.logEvent(name: name, parameters: parameters);
    } catch (_) {
      // Analytics must never block a user-facing action.
    }
  }

  Future<NotificationSettings> requestNotificationPermission() {
    return messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  Future<NotificationSettings> getNotificationSettings() {
    return messaging.getNotificationSettings();
  }

  Future<String?> getMessagingToken() => messaging.getToken();

  Future<void> configureRemoteConfig() async {
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 15),
        minimumFetchInterval: const Duration(minutes: 5),
      ),
    );
    await remoteConfig.setDefaults(const {
      'max_journals': 10,
      'max_keywords': 12,
    });
    await remoteConfig.fetchAndActivate();
  }

  int getRemoteInt(String key) => remoteConfig.getInt(key);

  Future<UploadedPdfReport> uploadPdf({
    required Uint8List bytes,
    required String userId,
    required String topic,
  }) async {
    final safeUserId = userId.trim().replaceAll(RegExp(r'[/\\]+'), '_');
    if (safeUserId.isEmpty) {
      throw StateError('User ID is required for Firebase Storage reports.');
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeTopic = topic
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final filename =
        'dashboard_${safeTopic.isEmpty ? 'topic' : safeTopic}_$timestamp.pdf';
    final reference = storage.ref('report/$safeUserId/analysis/$filename');
    final snapshot = await reference.putData(
      bytes,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {'topic': topic},
      ),
    );
    if (snapshot.state != TaskState.success || snapshot.bytesTransferred <= 0) {
      throw StateError('Firebase Storage upload did not complete.');
    }
    final downloadUrl = await reference.getDownloadURL();
    return UploadedPdfReport(
      downloadUrl: downloadUrl,
      storagePath: reference.fullPath,
      bytesUploaded: snapshot.bytesTransferred,
    );
  }

  Future<List<UploadedReportFile>> listUploadedReports(String userId) async {
    final safeUserId = userId.trim().replaceAll(RegExp(r'[/\\]+'), '_');
    if (safeUserId.isEmpty) return const [];

    final result = await storage.ref('report/$safeUserId/analysis').listAll();
    final reports = await Future.wait(
      result.items.map((reference) async {
        final metadata = await reference.getMetadata();
        final downloadUrl = await reference.getDownloadURL();
        return UploadedReportFile(
          name: reference.name,
          storagePath: reference.fullPath,
          downloadUrl: downloadUrl,
          uploadedAt: metadata.timeCreated ?? metadata.updated,
          sizeBytes: metadata.size,
        );
      }),
    );

    reports.sort((a, b) {
      final aTime = a.uploadedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.uploadedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return reports;
  }

  Future<void> deleteUploadedReport(String storagePath) async {
    final trimmedPath = storagePath.trim();
    if (trimmedPath.isEmpty) return;
    await storage.ref(trimmedPath).delete();
  }

  Future<String> savePdfLocally(Uint8List bytes, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> recordHandledException() async {
    try {
      throw StateError('Lab 03 handled Crashlytics demonstration.');
    } catch (error, stackTrace) {
      await crashlytics.recordError(
        error,
        stackTrace,
        reason: 'Lab 03 handled exception demo',
        fatal: false,
      );
    }
  }

  void testCrash() {
    crashlytics.crash();
  }
}

class UploadedPdfReport {
  final String downloadUrl;
  final String storagePath;
  final int bytesUploaded;

  const UploadedPdfReport({
    required this.downloadUrl,
    required this.storagePath,
    required this.bytesUploaded,
  });
}

class UploadedReportFile {
  final String name;
  final String storagePath;
  final String downloadUrl;
  final DateTime? uploadedAt;
  final int? sizeBytes;

  const UploadedReportFile({
    required this.name,
    required this.storagePath,
    required this.downloadUrl,
    required this.uploadedAt,
    required this.sizeBytes,
  });
}
