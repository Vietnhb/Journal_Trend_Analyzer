# Journal Trend Analyzer

A Flutter mobile app for searching OpenAlex research publications and analyzing publication trends for a user-entered topic.

## Features

- Search OpenAlex works by topic with loading, error, and empty states.
- Browse OpenAlex search results with numbered pages of 50 publications.
- Sort loaded OpenAlex results by publication year, either high to low or low to high.
- View publication title, year, citation count, journal/source, authors, DOI, and abstract when available.
- Analyze publication counts by year with a bar chart and ranked year list.
- Review dashboard metrics for total publications, average citations, most active year, top journal, top author, and most influential paper.
- Show ranked lists for influential papers, journals, and authors.

## Tech Stack

- Flutter with Material 3
- Provider for state management
- `http` for OpenAlex API calls
- `fl_chart` for trend charts

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

## API Used

- Base URL: `https://api.openalex.org`
- Search endpoint: `GET /works?search=<topic>&per-page=50&page=<page>&sort=publication_year:<direction>`
- Analytics endpoint: `GET /works?search=<topic>&group_by=<field>`

The app uses OpenAlex public data directly from the mobile client. No API key is required.

## Scope Notes

Publication records are read from OpenAlex when the user searches.
