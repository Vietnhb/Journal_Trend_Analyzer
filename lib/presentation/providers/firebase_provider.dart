import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/app_notification.dart';
import '../../data/models/dashboard_report_data.dart';
import '../../data/services/dashboard_report_service.dart';
import '../../data/services/firebase_service.dart';
import '../../data/services/local_notification_service.dart';

class FirebaseProvider extends ChangeNotifier {
  FirebaseProvider({
    FirebaseService? firebaseService,
    DashboardReportService? reportService,
    LocalNotificationService? localNotificationService,
  }) : _firebase = firebaseService ?? FirebaseService.instance,
       _reportService = reportService ?? DashboardReportService(),
       _localNotifications =
           localNotificationService ?? LocalNotificationService.instance;

  final FirebaseService _firebase;
  final DashboardReportService _reportService;
  final LocalNotificationService _localNotifications;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;

  User? _user;
  bool _isInitialized = false;
  bool _isSigningIn = false;
  bool _isSigningOut = false;
  bool _isLoadingRemoteConfig = false;
  bool _isRequestingNotifications = false;
  bool _notificationsAuthorized = false;
  bool _isExporting = false;
  bool _isLoadingReports = false;
  String? _authError;
  String? _serviceError;
  String? _messagingToken;
  int _maxJournals = 10;
  int _maxKeywords = 12;
  String? _reportLocalPath;
  String? _reportDownloadUrl;
  String? _reportStoragePath;
  int? _reportUploadedBytes;
  DateTime? _reportUploadedAt;
  String? _deletingReportPath;
  final List<AppNotification> _notifications = [];
  List<UploadedReportFile> _uploadedReports = const [];

  User? get user => _user;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _user != null;
  bool get isSigningIn => _isSigningIn;
  bool get isSigningOut => _isSigningOut;
  bool get isLoadingRemoteConfig => _isLoadingRemoteConfig;
  bool get isRequestingNotifications => _isRequestingNotifications;
  bool get notificationsAuthorized => _notificationsAuthorized;
  bool get isExporting => _isExporting;
  bool get isLoadingReports => _isLoadingReports;
  String? get authError => _authError;
  String? get serviceError => _serviceError;
  String? get messagingToken => _messagingToken;
  int get maxJournals => _maxJournals;
  int get maxKeywords => _maxKeywords;
  String? get reportLocalPath => _reportLocalPath;
  String? get reportDownloadUrl => _reportDownloadUrl;
  String? get reportStoragePath => _reportStoragePath;
  int? get reportUploadedBytes => _reportUploadedBytes;
  DateTime? get reportUploadedAt => _reportUploadedAt;
  String? get deletingReportPath => _deletingReportPath;
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  List<UploadedReportFile> get uploadedReports =>
      List.unmodifiable(_uploadedReports);

  Future<void> initialize() async {
    if (_isInitialized) return;

    _user = _firebase.currentUser;
    _authSubscription = _firebase.authStateChanges.listen((user) {
      _user = user;
      if (user == null) {
        _uploadedReports = const [];
      } else {
        unawaited(loadUploadedReports());
      }
      notifyListeners();
    });

    _isInitialized = true;
    notifyListeners();
    unawaited(refreshRemoteConfig());
    if (_user != null) {
      unawaited(loadUploadedReports());
    }
    unawaited(_localNotifications.initialize());
    unawaited(_initializeMessaging());
  }

  Future<bool> signInWithGoogle() async {
    if (_isSigningIn) return false;
    _isSigningIn = true;
    _authError = null;
    notifyListeners();

    try {
      final credential = await _firebase.signInWithGoogle();
      _user = credential.user;
      if (_user != null) {
        await enableNotifications();
        await loadUploadedReports();
      }
      return _user != null;
    } catch (error, stackTrace) {
      _authError = _friendlyFirebaseError(error);
      await _firebase.crashlytics.recordError(
        error,
        stackTrace,
        reason: 'Google Sign-In failed',
        fatal: false,
      );
      return false;
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (_isSigningOut) return;
    _isSigningOut = true;
    _serviceError = null;
    notifyListeners();

    try {
      await _firebase.signOut();
      _user = null;
      _uploadedReports = const [];
    } catch (error) {
      _serviceError = _friendlyFirebaseError(error);
    } finally {
      _isSigningOut = false;
      notifyListeners();
    }
  }

  Future<void> refreshRemoteConfig() async {
    if (_isLoadingRemoteConfig) return;
    _isLoadingRemoteConfig = true;
    _serviceError = null;
    notifyListeners();

    try {
      await _firebase.configureRemoteConfig();
      _maxJournals = _firebase.getRemoteInt('max_journals');
      _maxKeywords = _firebase.getRemoteInt('max_keywords');
    } catch (error) {
      _serviceError = 'Remote Config: ${_friendlyFirebaseError(error)}';
    } finally {
      _isLoadingRemoteConfig = false;
      notifyListeners();
    }
  }

  Future<void> exportDashboard(DashboardReportData data) async {
    if (_isExporting) return;
    if (_user == null) {
      _serviceError = 'PDF export: sign in before uploading reports.';
      notifyListeners();
      return;
    }
    _isExporting = true;
    _serviceError = null;
    _reportLocalPath = null;
    _reportDownloadUrl = null;
    _reportStoragePath = null;
    _reportUploadedBytes = null;
    _reportUploadedAt = null;
    notifyListeners();

    try {
      final bytes = await _reportService.build(data);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'journal_dashboard_$timestamp.pdf';
      _reportLocalPath = await _firebase.savePdfLocally(bytes, filename);
      final uploadedReport = await _firebase.uploadPdf(
        bytes: bytes,
        userId: _user!.uid,
        topic: data.topic,
      );
      _reportDownloadUrl = uploadedReport.downloadUrl;
      _reportStoragePath = uploadedReport.storagePath;
      _reportUploadedBytes = uploadedReport.bytesUploaded;
      _reportUploadedAt = DateTime.now();
      await loadUploadedReports();
      await _firebase.logEvent('export_pdf', parameters: {'topic': data.topic});
    } catch (error, stackTrace) {
      final localMessage = _reportLocalPath == null
          ? ''
          : ' The PDF was saved on this device.';
      _serviceError =
          'PDF export: ${_friendlyFirebaseError(error)}$localMessage';
      await _firebase.crashlytics.recordError(
        error,
        stackTrace,
        reason: 'Dashboard PDF export failed',
        fatal: false,
      );
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  Future<void> loadUploadedReports() async {
    final user = _user;
    if (user == null || _isLoadingReports) return;
    _isLoadingReports = true;
    _serviceError = null;
    notifyListeners();

    try {
      _uploadedReports = await _firebase.listUploadedReports(user.uid);
    } catch (error) {
      _serviceError = 'Report history: ${_friendlyFirebaseError(error)}';
    } finally {
      _isLoadingReports = false;
      notifyListeners();
    }
  }

  Future<void> deleteUploadedReport(UploadedReportFile report) async {
    if (_deletingReportPath != null) return;
    _deletingReportPath = report.storagePath;
    _serviceError = null;
    notifyListeners();

    try {
      await _firebase.deleteUploadedReport(report.storagePath);
      _uploadedReports = _uploadedReports
          .where((item) => item.storagePath != report.storagePath)
          .toList(growable: false);
      if (_reportStoragePath == report.storagePath) {
        _reportDownloadUrl = null;
        _reportStoragePath = null;
        _reportUploadedBytes = null;
        _reportUploadedAt = null;
      }
    } catch (error) {
      _serviceError = 'Delete report: ${_friendlyFirebaseError(error)}';
    } finally {
      _deletingReportPath = null;
      notifyListeners();
    }
  }

  Future<void> recordHandledException() async {
    _serviceError = null;
    try {
      await _firebase.recordHandledException();
    } catch (error) {
      _serviceError = _friendlyFirebaseError(error);
    }
    notifyListeners();
  }

  void testCrash() => _firebase.testCrash();

  void clearNotifications() {
    if (_notifications.isEmpty) return;
    _notifications.clear();
    notifyListeners();
  }

  Future<void> enableNotifications() async {
    if (_isRequestingNotifications) return;
    _isRequestingNotifications = true;
    _serviceError = null;
    notifyListeners();

    try {
      final settings = await _firebase.requestNotificationPermission();
      _notificationsAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      _messagingToken = await _firebase.getMessagingToken();
    } catch (error) {
      _serviceError = 'FCM: ${_friendlyFirebaseError(error)}';
    } finally {
      _isRequestingNotifications = false;
      notifyListeners();
    }
  }

  Future<void> _initializeMessaging() async {
    try {
      final settings = await _firebase.getNotificationSettings();
      _notificationsAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      _messagingToken = await _firebase.getMessagingToken();

      _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
        _addNotification(message);
        unawaited(_localNotifications.showRemoteMessage(message));
      });
      _openedMessageSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _addNotification,
      );

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) _addNotification(initialMessage);
    } catch (error) {
      _serviceError = 'FCM: ${_friendlyFirebaseError(error)}';
    }
  }

  void _addNotification(RemoteMessage message) {
    final notification = message.notification;
    final title =
        notification?.title ?? message.data['title']?.toString() ?? 'Update';
    final body =
        notification?.body ??
        message.data['body']?.toString() ??
        'A Firebase Cloud Messaging notification was received.';
    final id =
        message.messageId ??
        '${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';

    if (_notifications.any((item) => item.id == id)) return;
    _notifications.insert(
      0,
      AppNotification(
        id: id,
        title: title,
        body: body,
        receivedAt: message.sentTime ?? DateTime.now(),
      ),
    );
    notifyListeners();
  }

  String _friendlyFirebaseError(Object error) {
    if (error is FirebaseException &&
        error.plugin == 'firebase_storage' &&
        error.code == 'object-not-found') {
      return 'Firebase Storage bucket is unavailable. Upgrade the Firebase '
          'project to Blaze, open Storage and create the default bucket, '
          'then try again.';
    }
    if (error is FirebaseException &&
        error.plugin == 'firebase_storage' &&
        error.code == 'unauthorized') {
      return 'Firebase Storage rules blocked the upload. Publish storage.rules '
          'for this project, then try again.';
    }
    if (error is FirebaseAuthException) {
      return error.message ?? error.code;
    }
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('serverClientId must be provided') ||
        message.contains('clientConfigurationError')) {
      return 'Google Sign-In is not configured yet. Add the Android SHA '
          'fingerprints in Firebase Console, enable Google Authentication, '
          'then replace android/app/google-services.json.';
    }
    return message;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _messageSubscription?.cancel();
    _openedMessageSubscription?.cancel();
    super.dispose();
  }
}
