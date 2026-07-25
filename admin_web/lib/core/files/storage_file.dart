import 'dart:typed_data';

const pdfContentType = 'application/pdf';

final class StorageFileException implements Exception {
  const StorageFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class ValidatedStorageFile {
  const ValidatedStorageFile._({
    required this.name,
    required this.contentType,
    required this.bytes,
  });

  factory ValidatedStorageFile.pdf({
    required String name,
    required Uint8List bytes,
    required int expectedSize,
    String? responseContentType,
  }) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty ||
        normalizedName.contains('/') ||
        normalizedName.contains(r'\')) {
      throw const StorageFileException('The Storage file name is invalid.');
    }
    if (bytes.length != expectedSize) {
      throw StorageFileException(
        'The download is incomplete (${bytes.length}/$expectedSize bytes).',
      );
    }
    final contentType = _normalizedContentType(responseContentType);
    if (contentType != null && contentType != pdfContentType) {
      throw StorageFileException(
        'The server returned “$contentType” instead of a PDF.',
      );
    }
    if (!_containsPdfSignature(bytes)) {
      throw const StorageFileException(
        'The file does not contain a valid PDF signature.',
      );
    }
    return ValidatedStorageFile._(
      name: normalizedName,
      contentType: pdfContentType,
      bytes: Uint8List.fromList(bytes),
    );
  }

  final String name;
  final String contentType;
  final Uint8List bytes;

  static String? _normalizedContentType(String? value) {
    final normalized = value?.split(';').first.trim().toLowerCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static bool _containsPdfSignature(Uint8List bytes) {
    const signature = <int>[0x25, 0x50, 0x44, 0x46, 0x2D]; // %PDF-
    final searchLength = bytes.length < 1024 ? bytes.length : 1024;
    for (var offset = 0; offset <= searchLength - signature.length; offset++) {
      var matches = true;
      for (var index = 0; index < signature.length; index++) {
        if (bytes[offset + index] != signature[index]) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
  }
}
