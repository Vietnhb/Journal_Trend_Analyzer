# Journal Trend Analyzer

A Flutter mobile app for searching OpenAlex research publications and analyzing publication trends for a user-entered topic.

## Features

- Search OpenAlex works from Home with loading, error, empty states, and recent searches.
- Review the selected topic dashboard directly on Home with trend, metrics, top journal, top author, and influential papers.
- Browse OpenAlex search results with numbered pages of 50 publications.
- Sort loaded OpenAlex results by publication year, either high to low or low to high.
- View publication title, year, citation count, journal/source, authors, DOI, and abstract when available.
- Analyze publication counts by year with a bar chart and ranked year list.
- Review dashboard metrics for total publications, average citations for the latest 100 works, most active year, top journal, top author, and most influential paper.
- Show ranked lists for influential papers, journals, and authors.
- Authenticate users with Firebase Authentication and Google Sign-In.
- Receive Firebase Cloud Messaging notifications in the Profile notification center.
- Export dashboard analytics to PDF and upload reports to Firebase Storage.
- Track the required Lab 03 Firebase Analytics events.
- Display Firebase Remote Config values and provide Crashlytics demonstrations.
- Cover the 11 required E2E scenarios with Patrol test scripts.

## App Navigation

- Home: Search Topic + Research Dashboard
- Journals: Journal rankings, contribution chart, and journal drill-down
- Keywords: Trending keyword rankings and keyword detail analytics
- Profile: User account, notifications, PDF export, Remote Config, Crashlytics, and preferences

## Selected Diagrams

- Publication Trend: publications grouped by publication year.
- Journal Ranking: top journals by publication count.
- Top Authors: top contributing authors by publication count.
- Top Influential Papers: top publications by citation count.
- Research Trend Dashboard: summary cards for the selected topic.

## Tech Stack

- Flutter with Material 3
- Provider for state management
- `http` for OpenAlex API calls
- `fl_chart` for trend charts
- Firebase Authentication, Storage, Cloud Messaging, Analytics, Crashlytics, and Remote Config
- Patrol for Android E2E testing

## Folder Structure

```text
lib/
  main.dart
  core/
    constants/
    errors/
    widgets/
  data/
    models/
    repositories/
    services/
  presentation/
    providers/
    screens/
    trends/
    widgets/
```

## How To Run

```bash
flutter pub get
flutter run
```

Run on an Android emulator or a physical Android device with internet access.
Complete the Firebase Console steps in `LAB03_FIREBASE_SETUP.md` before testing
Google Sign-In and cloud services.

## Patrol

```powershell
$env:ANDROID_HOME='D:\Android_Studio_SDK'
$env:Path="$env:ANDROID_HOME\platform-tools;$env:LOCALAPPDATA\Pub\Cache\bin;$env:Path"
patrol test --device emulator-5554
```

## API Used

- Base URL: `https://api.openalex.org`
- Search endpoint: `GET /works?search=<topic>&per-page=50&page=<page>&sort=publication_year:<direction>&filter=to_publication_date:<current-year>-12-31`
- Analytics endpoint: `GET /works?search=<topic>&group_by=<field>&filter=to_publication_date:<current-year>-12-31`
- Average citation endpoint: `GET /works?search=<topic>&per-page=100&sort=publication_year:desc&select=cited_by_count&filter=to_publication_date:<current-year>-12-31`

The app uses OpenAlex public data directly from the mobile client. No API key is required.

## Scope Notes

Publication records and aggregate counts are read from OpenAlex when the user searches. Citation counts are shown for individual publications and top influential papers using OpenAlex `cited_by_count`. The dashboard average citation metric is calculated from the latest 100 OpenAlex works for the searched topic (`publication_year:desc`). The app does not walk every cursor page to compute whole-corpus citation totals because broad topics can contain millions of works and trigger OpenAlex rate limits on a mobile client.

OpenAlex can contain future-year metadata from upstream sources. The app filters API requests to `to_publication_date:<current-year>-12-31` using `DateTime.now().year`, and the provider also ignores any remaining publication year greater than the current year before rendering search results, trend charts, rankings, and dashboard metrics.

OpenAlex may temporarily rate-limit or slow down after repeated searches. API calls are kept bounded and retried with a short backoff; if a rate limit was recently hit, wait briefly before retrying.
