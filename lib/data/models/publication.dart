class Publication {
  final String id;
  final String title;
  final int year;
  final int citationCount;
  final String journal;

  Publication({
    required this.id,
    required this.title,
    required this.year,
    required this.citationCount,
    required this.journal,
  });

  // Factory to create from dummy data for testing Trend Analysis
  factory Publication.dummy(int year) {
    return Publication(
      id: 'dummy_$year\_${DateTime.now().microsecondsSinceEpoch}',
      title: 'Sample Publication $year',
      year: year,
      citationCount: 10,
      journal: 'Dummy Journal',
    );
  }
}
