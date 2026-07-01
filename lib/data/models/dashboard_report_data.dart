import 'publication.dart';
import 'ranked_entity.dart';

class DashboardReportData {
  final String topic;
  final int totalPublications;
  final int? averageCitations;
  final int? mostActiveYear;
  final String? topJournal;
  final String? topAuthor;
  final Publication? mostInfluentialPublication;
  final Map<int, int> publicationsByYear;
  final List<RankedEntity> journals;
  final List<Publication> publications;

  const DashboardReportData({
    required this.topic,
    required this.totalPublications,
    required this.averageCitations,
    required this.mostActiveYear,
    required this.topJournal,
    required this.topAuthor,
    required this.mostInfluentialPublication,
    required this.publicationsByYear,
    required this.journals,
    required this.publications,
  });
}
