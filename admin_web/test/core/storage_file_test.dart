import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_admin_web/core/core.dart';

void main() {
  group('ValidatedStorageFile.pdf', () {
    final pdf = Uint8List.fromList(<int>[
      0x25,
      0x50,
      0x44,
      0x46,
      0x2D,
      0x31,
      0x2E,
      0x37,
      0x0A,
    ]);

    test('accepts exact PDF bytes and a parameterized MIME type', () {
      final file = ValidatedStorageFile.pdf(
        name: 'report.pdf',
        bytes: pdf,
        expectedSize: pdf.length,
        responseContentType: 'application/pdf; charset=binary',
      );

      expect(file.name, 'report.pdf');
      expect(file.contentType, pdfContentType);
      expect(file.bytes, orderedEquals(pdf));
    });

    test('accepts a PDF signature within the first 1024 bytes', () {
      final bytes = Uint8List.fromList(<int>[0, 0, ...pdf]);

      expect(
        () => ValidatedStorageFile.pdf(
          name: 'report.pdf',
          bytes: bytes,
          expectedSize: bytes.length,
        ),
        returnsNormally,
      );
    });

    test('rejects incomplete bytes', () {
      expect(
        () => ValidatedStorageFile.pdf(
          name: 'report.pdf',
          bytes: pdf,
          expectedSize: pdf.length + 1,
        ),
        throwsA(isA<StorageFileException>()),
      );
    });

    test('rejects a mislabeled or invalid payload', () {
      expect(
        () => ValidatedStorageFile.pdf(
          name: 'report.pdf',
          bytes: Uint8List.fromList('not a pdf'.codeUnits),
          expectedSize: 9,
          responseContentType: 'text/plain',
        ),
        throwsA(isA<StorageFileException>()),
      );
    });

    test('rejects a path masquerading as a file name', () {
      expect(
        () => ValidatedStorageFile.pdf(
          name: '../report.pdf',
          bytes: pdf,
          expectedSize: pdf.length,
        ),
        throwsA(isA<StorageFileException>()),
      );
    });
  });
}
