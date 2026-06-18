/// Centralized limits for OpenAlex requests, rankings, and pagination.
///
/// Keep API constraints separate from product defaults so changing a visible
/// ranking size does not accidentally violate an OpenAlex endpoint limit.
abstract final class AppLimits {
  /// Maximum page size supported by regular OpenAlex list endpoints.
  static const int openAlexListPageSize = 50;

  /// Maximum page size supported by OpenAlex `group_by` responses.
  static const int openAlexGroupPageSize = 200;

  /// Number of publications loaded and displayed per page.
  static const int publicationPageSize = openAlexListPageSize;

  /// Maximum directly addressable OpenAlex page from either end.
  static const int directPageNavigationLimit = 200;

  /// Product defaults for ranked/search results.
  static const int topJournalResults = openAlexListPageSize;
  static const int topAuthorResults = openAlexListPageSize;
  static const int topPaperResults = openAlexListPageSize;
  static const int trendingKeywordResults = 12;
  static const int keywordAnalyticsCardLimit = 10;

  /// Default for reusable lower-level ranking helpers.
  static const int rankedEntityResults = 10;
}
