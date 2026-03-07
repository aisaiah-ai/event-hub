import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../config/firestore_config.dart';
import 'speaker_model.dart';

/// Fetches speaker documents from Firestore.
/// When [eventId] is provided, reads from events/{eventId}/speakers/{id};
/// otherwise reads from top-level speakers/{id}.
/// Uses in-app mock profile for March Assembly speakers when Firestore doc is missing.
class SpeakerRepository {
  SpeakerRepository() : _firestore = FirestoreConfig.instanceOrNull;

  final FirebaseFirestore? _firestore;

  static const String _speakersCollection = 'speakers';
  static const String _eventsCollection = 'events';

  /// March Assembly event IDs (for fallback mock speakers).
  static const String _marchAssemblyId = 'march-assembly';
  static const String _marchClusterSlug = 'march-cluster-2026';

  static bool _isMarchAssembly(String? eventId, String? slug) {
    if (eventId == _marchAssemblyId) return true;
    if (slug == _marchClusterSlug) return true;
    return false;
  }

  /// In-app mock speaker profiles for March Assembly (when seed not run).
  static Speaker? _fallbackSpeaker(String id) {
    switch (id) {
      case 'rommel-dolar':
        return const Speaker(
          id: 'rommel-dolar',
          fullName: 'Rommel Dolar',
          displayName: 'Bro Rommel Dolar',
          title: 'House Hold Head',
          cluster: 'Central B Cluster',
          photoUrl: 'assets/images/speakers/rommel_dolar.png',
          bio:
              'Bro Rommel serves as House Hold Head for the Central B Cluster, supporting families in BBS, Tampa, and Port Charlotte. '
              'He has been active in Couples for Christ for over a decade, with a heart for evangelization and community building.',
          yearsInCfc: 12,
          familiesMentored: 8,
          talksGiven: 24,
          location: 'Tampa, FL',
          topics: [
            'Evangelization',
            'Household Leadership',
            'Community Life',
            'Worship',
          ],
          quote:
              'In the One we are one — when we walk together in Christ, our families and our cluster become a light to the world.',
          email: 'rommel.dolar@example.com',
          phone: '+1 (813) 555-0101',
          facebookUrl: 'https://www.facebook.com/example.rommel',
        );
      case 'mike-suela':
        return const Speaker(
          id: 'mike-suela',
          fullName: 'Mike Suela',
          displayName: 'Bro. Mike Suela',
          title: 'Unit Head',
          cluster: 'Central B Cluster',
          photoUrl: 'assets/images/speakers/mike_suela.png',
          bio:
              'Bro. Mike Suela leads as Unit Head, coordinating birthdays, anniversaries, and fellowship events for the cluster. '
              'He is passionate about celebrating milestones and strengthening bonds within the community.',
          yearsInCfc: 8,
          familiesMentored: 5,
          talksGiven: 12,
          location: 'Port Charlotte, FL',
          topics: ['Fellowship', 'Celebration', 'Family Life', 'Service'],
          quote:
              'Every birthday and anniversary is a chance to thank God for His faithfulness and to encourage one another in the mission.',
          email: 'mike.suela@example.com',
          phone: '+1 (941) 555-0102',
        );
      default:
        return null;
    }
  }

  /// Fetches a speaker by ID.
  /// When [eventId] is set, reads from events/{eventId}/speakers/{id} (event-level speakers).
  /// When [eventId] is null, reads from top-level speakers/{id}.
  /// For March Assembly, returns in-app mock profile if Firestore doc is missing.
  /// Throws if the document does not exist and no fallback is available.
  Future<Speaker> getSpeakerById(
    String id, {
    String? eventId,
    String? eventSlug,
  }) async {
    final fs = _firestore;
    if (fs != null) {
      final DocumentReference<Map<String, dynamic>> ref = eventId != null
          ? fs
                .collection(_eventsCollection)
                .doc(eventId)
                .collection(_speakersCollection)
                .doc(id)
          : fs.collection(_speakersCollection).doc(id);
      final snap = await ref.get();
      if (snap.exists && snap.data() != null) {
        return Speaker.fromFirestore(snap.id, snap.data()!);
      }
    }
    // Fallback: March Assembly mock profiles when Firestore doc missing or Firestore unavailable.
    if (_isMarchAssembly(eventId, eventSlug)) {
      final fallback = _fallbackSpeaker(id);
      if (fallback != null) return fallback;
    }
    throw StateError('Speaker not found: $id');
  }
}
