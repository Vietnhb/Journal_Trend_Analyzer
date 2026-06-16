# Journal Trend Analyzer

A Flutter mobile app for searching research publications from OpenAlex and analyzing publication trends for a user-entered topic.

## Features

- Search OpenAlex works by topic with loading, error, and empty states.
- View publication title, year, citation count, journal/source, authors, DOI, and abstract when available.
- Analyze publication counts by year with a bar chart.
- Research dashboard with total publications, average citations, most active year, top journal, top author, and most influential paper.
- Ranked lists for top influential papers, research journals, and contributing authors.

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
    utils/ (tạo sau nếu cần)

  data/
    models/ (Step 1)
    services/ (Step 1)
    repositories/ (Step 1)

  presentation/
    providers/ (Step 2)
    screens/
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
- Endpoint: `GET /works?search=<topic>&per_page=100`

The app uses OpenAlex public data directly from the mobile client. No API key is required.

## Scope Notes

This project has no backend, no authentication, no Firebase, no database, and no hardcoded publication dataset or fake fallback data.
