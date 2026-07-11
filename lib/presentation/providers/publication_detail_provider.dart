import 'dart:async';

import '../../data/models/publication.dart';
import '../../data/services/firebase_service.dart';

class PublicationDetailProvider {
  const PublicationDetailProvider._();

  static void trackView(Publication publication) {
    unawaited(
      FirebaseService.instance.logEvent(
        'view_publication',
        parameters: {
          'publication_title': publication.title,
          if (publication.year != null) 'publication_year': publication.year!,
        },
      ),
    );
  }
}
