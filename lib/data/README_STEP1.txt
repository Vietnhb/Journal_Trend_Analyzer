Step 1 (Minh) – OpenAlex Data Layer

Cần tạo (theo P2.md):
- lib/data/models/publication.dart
- lib/data/services/openalex_api_service.dart
- lib/data/repositories/publication_repository.dart

Yêu cầu:
- OpenAlex gọi trực tiếp từ mobile client (không backend)
- Parse JSON theo fields: title, year, citationCount, journal/source, authors, DOI, abstract
- Xử lý error/timeout/no-internet/invalid JSON

