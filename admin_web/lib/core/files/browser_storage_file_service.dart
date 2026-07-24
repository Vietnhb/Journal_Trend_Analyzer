import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'storage_file.dart';

final class BrowserStorageFileService {
  final Set<String> _objectUrls = <String>{};

  void previewUrl(String value) {
    final url = _validatedFirebaseStorageUrl(value);
    web.window.open(url.toString(), '_blank', 'noopener');
  }

  Future<void> downloadFromUrl({
    required String url,
    required String name,
    required int expectedSize,
  }) async {
    final source = _validatedFirebaseStorageUrl(url);
    final response = await web.window.fetch(source.toString().toJS).toDart;
    if (!response.ok) {
      throw StorageFileException(
        'Không thể tải tệp từ Firebase Storage (HTTP ${response.status}).',
      );
    }
    final bytes = (await response.arrayBuffer().toDart).toDart.asUint8List();
    final file = ValidatedStorageFile.pdf(
      name: name,
      bytes: bytes,
      expectedSize: expectedSize,
      responseContentType: response.headers.get('content-type'),
    );
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

  Uri _validatedFirebaseStorageUrl(String value) {
    final url = Uri.tryParse(value);
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'firebasestorage.googleapis.com' ||
        url.pathSegments.length < 5 ||
        url.queryParameters['alt'] != 'media' ||
        url.queryParameters['token']?.isNotEmpty != true) {
      throw const StorageFileException(
        'Liên kết Firebase Storage không hợp lệ.',
      );
    }
    return url;
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
