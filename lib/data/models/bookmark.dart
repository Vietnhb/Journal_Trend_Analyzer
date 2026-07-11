import 'journal_profile.dart';
import 'publication.dart';

class JournalBookmark {
  final JournalProfile profile;
  final String id;
  final String name;
  final String? publisher;
  final String? countryCode;
  final String? issnL;
  final int worksCount;
  final int citedByCount;
  final DateTime savedAt;

  const JournalBookmark({
    required this.profile,
    required this.id,
    required this.name,
    required this.publisher,
    required this.countryCode,
    required this.issnL,
    required this.worksCount,
    required this.citedByCount,
    required this.savedAt,
  });

  factory JournalBookmark.fromProfile(
    JournalProfile profile, {
    DateTime? savedAt,
  }) {
    return JournalBookmark(
      profile: profile,
      id: profile.id,
      name: profile.name,
      publisher: profile.publisher,
      countryCode: profile.countryCode,
      issnL: profile.issnL,
      worksCount: profile.worksCount,
      citedByCount: profile.citedByCount,
      savedAt: savedAt ?? DateTime.now(),
    );
  }

  factory JournalBookmark.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'];
    final profile = profileJson is Map<String, dynamic>
        ? JournalProfile.fromBookmarkJson(profileJson)
        : JournalProfile.fromBookmarkJson(json);
    return JournalBookmark(
      profile: profile,
      id: profile.id,
      name: profile.name,
      publisher: profile.publisher,
      countryCode: profile.countryCode,
      issnL: profile.issnL,
      worksCount: profile.worksCount,
      citedByCount: profile.citedByCount,
      savedAt:
          DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'publisher': publisher,
      'countryCode': countryCode,
      'issnL': issnL,
      'worksCount': worksCount,
      'citedByCount': citedByCount,
      'savedAt': savedAt.toIso8601String(),
      'profile': profile.toBookmarkJson(),
    };
  }

  JournalProfile toInitialProfile() {
    return profile;
  }
}

class PublicationBookmark {
  final Publication publication;
  final DateTime savedAt;

  const PublicationBookmark({required this.publication, required this.savedAt});

  factory PublicationBookmark.fromPublication(Publication publication) {
    return PublicationBookmark(
      publication: publication,
      savedAt: DateTime.now(),
    );
  }

  factory PublicationBookmark.fromJson(Map<String, dynamic> json) {
    final publicationJson = json['publication'];
    return PublicationBookmark(
      publication: Publication.fromBookmarkJson(
        publicationJson is Map<String, dynamic>
            ? publicationJson
            : const <String, dynamic>{},
      ),
      savedAt:
          DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'publication': publication.toBookmarkJson(),
      'savedAt': savedAt.toIso8601String(),
    };
  }
}
