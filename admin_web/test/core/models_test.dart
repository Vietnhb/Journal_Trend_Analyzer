import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_admin_web/core/core.dart';

void main() {
  group('API models', () {
    test('Remote Config preserves nullable client limits', () {
      final data = RemoteConfigData.fromJson({
        'etag': 'etag-1',
        'version': {'versionNumber': 12, 'updatedAt': '2026-07-23T10:00:00Z'},
        'parameters': {'maxJournals': null, 'maxKeywords': 25},
        'allParameters': [
          {
            'key': 'max_journals',
            'value': null,
            'description': 'Maximum journals',
            'valueType': 'NUMBER',
            'group': null,
          },
        ],
      });

      expect(data.etag, 'etag-1');
      expect(data.version.versionNumber, '12');
      expect(data.parameters.maxJournals, isNull);
      expect(data.parameters.maxKeywords, 25);
      expect(data.allParameters.single.value, isNull);
    });

    test('Analytics model defaults missing metrics without losing status', () {
      final data = AnalyticsData.fromJson({
        'status': 'unconfigured',
        'reason': 'Set GA4_PROPERTY_ID.',
        'summary': const <String, Object?>{},
        'events': const [],
        'daily': const [],
      });

      expect(data.status, IntegrationStatus.unconfigured);
      expect(data.reason, contains('GA4_PROPERTY_ID'));
      expect(data.summary.activeUsers, 0);
      expect(data.events, isEmpty);
    });

    test('Analytics exposes the initial BigQuery export as pending', () {
      final data = AnalyticsData.fromJson({
        'status': 'pending',
        'reason': 'Waiting for analytics_542374527.',
        'summary': const <String, Object?>{},
        'events': const [],
        'daily': const [],
      });

      expect(data.status, IntegrationStatus.pending);
      expect(data.reason, contains('analytics_542374527'));
    });

    test('Analytics identifies the scoped GA4 Android stream', () {
      final data = AnalyticsData.fromJson({
        'status': 'ready',
        'reason': 'Scoped Android analytics.',
        'source': {'propertyId': '520062234', 'streamId': '15254447622'},
        'summary': const <String, Object?>{},
        'events': const [],
        'daily': const [],
        'eventDaily': const [],
      });

      expect(data.source.propertyId, '520062234');
      expect(data.source.streamId, '15254447622');
    });

    test('UserUpdate distinguishes omitted and explicitly cleared name', () {
      expect(
        const UserUpdate(clearDisplayName: true, disabled: true).toJson(),
        {'displayName': null, 'disabled': true},
      );
      expect(() => const UserUpdate().toJson(), throwsArgumentError);
    });

    test('report and user pages parse nullable paging tokens', () {
      final users = UserPage.fromJson({
        'users': [
          {
            'uid': 'uid-1',
            'email': 'admin@example.com',
            'phoneNumber': null,
            'displayName': null,
            'photoURL': null,
            'disabled': false,
            'emailVerified': true,
            'admin': true,
            'providers': ['google.com'],
            'createdAt': '2026-07-01T00:00:00Z',
            'lastSignInAt': null,
            'lastRefreshAt': null,
          },
        ],
        'nextPageToken': null,
      });
      final reports = ReportPage.fromJson({
        'reports': const [
          {
            'path': 'report/uid-1/analysis/report.pdf',
            'name': 'report.pdf',
            'ownerUid': 'uid-1',
            'ownerEmail': 'user@example.com',
            'topic': 'AI',
            'sizeBytes': 1024,
            'contentType': 'application/pdf',
            'generation': '1700000000000000',
            'createdAt': null,
            'updatedAt': null,
          },
        ],
        'nextPageToken': 'next',
      });

      expect(users.users.single.isAdmin, isTrue);
      expect(users.users.single.createdAt, '2026-07-01T00:00:00Z');
      expect(users.nextPageToken, isNull);
      expect(reports.nextPageToken, 'next');
      expect(reports.reports.single.path, contains('/analysis/'));

      final deletion = ReportBulkDeleteResult.fromJson({
        'deleted': ['report/uid-1/analysis/report.pdf'],
        'failed': const [
          {
            'path': 'report/uid-2/analysis/stale.pdf',
            'code': 'report_generation_conflict',
          },
        ],
      });
      expect(deletion.deleted, hasLength(1));
      expect(deletion.failed.single.code, 'report_generation_conflict');
    });

    test('messaging campaign parses scheduling and delivery state', () {
      final campaign = MessagingCampaign.fromJson({
        'id': 'campaign-1',
        'name': 'July release',
        'title': 'New report',
        'body': 'Monthly reports are ready.',
        'data': {'screen': 'reports'},
        'audience': 'platform_android',
        'status': 'scheduled',
        'ttlSeconds': 86400,
        'sound': true,
        'scheduleAt': '2026-07-25T08:00:00Z',
        'createdAt': '2026-07-24T08:00:00Z',
        'sentAt': null,
        'canceledAt': null,
        'messageId': null,
        'errorCode': null,
      });

      expect(campaign.audience, CampaignAudience.android);
      expect(campaign.status, CampaignStatus.scheduled);
      expect(campaign.scheduleAt, isNotNull);
      expect(campaign.data['screen'], 'reports');
    });
  });
}
