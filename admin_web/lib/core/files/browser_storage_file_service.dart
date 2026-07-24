import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'storage_file.dart';

final class BrowserStorageFileService {
  final Set<String> _objectUrls = <String>{};

  void previewFile(ValidatedStorageFile file) {
    final objectUrl = _createObjectUrl(file);
    final anchor = web.HTMLAnchorElement()
      ..href = objectUrl
      ..target = '_blank'
      ..rel = 'noopener';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    _scheduleRelease(objectUrl, const Duration(minutes: 5));
  }

  void downloadFile(ValidatedStorageFile file) {
    final objectUrl = _createObjectUrl(file);
    final anchor = web.HTMLAnchorElement()
      ..href = objectUrl
      ..download = file.name
      ..rel = 'noopener';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    _scheduleRelease(objectUrl, const Duration(minutes: 1));
  }

  String _createObjectUrl(ValidatedStorageFile file) {
    // Copy to an exact-length buffer. This avoids passing a Dart List or a
    // larger backing buffer to Blob, both of which can corrupt binary files.
    final exactBytes = Uint8List.fromList(file.bytes);
    final blob = web.Blob(
      <web.BlobPart>[exactBytes.buffer.toJS].toJS,
      web.BlobPropertyBag(type: file.contentType),
    );
    if (blob.size != exactBytes.length) {
      throw const StorageFileException(
        'Trình duyệt không thể tạo tệp nhị phân đầy đủ.',
      );
    }
    final objectUrl = web.URL.createObjectURL(blob);
    _objectUrls.add(objectUrl);
    return objectUrl;
  }

  void _scheduleRelease(String objectUrl, Duration delay) {
    Timer(delay, () {
      if (_objectUrls.remove(objectUrl)) {
        web.URL.revokeObjectURL(objectUrl);
      }
    });
  }
}
