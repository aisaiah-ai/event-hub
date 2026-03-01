/// Full speaker document from Firestore collection: speakers/{speakerId}.
class Speaker {
  const Speaker({
    required this.id,
    this.fullName = '',
    this.displayName,
    this.title,
    this.cluster,
    this.photoUrl,
    this.bio,
    this.yearsInCfc,
    this.familiesMentored,
    this.talksGiven,
    this.location,
    this.topics = const [],
    this.quote,
    this.email,
    this.phone,
    this.facebookUrl,
  });

  final String id;
  final String fullName;
  final String? displayName;
  final String? title;
  final String? cluster;
  final String? photoUrl;
  final String? bio;
  final int? yearsInCfc;
  final int? familiesMentored;
  final int? talksGiven;
  final String? location;
  final List<String> topics;
  final String? quote;
  final String? email;
  final String? phone;
  final String? facebookUrl;

  /// Display name for UI: displayName if set, else fullName.
  String get effectiveDisplayName => displayName?.trim().isNotEmpty == true
      ? displayName!
      : (fullName.trim().isNotEmpty ? fullName : 'Speaker');

  /// Create from Firestore document snapshot data.
  factory Speaker.fromFirestore(String id, Map<String, dynamic> data) {
    final topicsRaw = data['topics'];
    final topicsList = <String>[];
    if (topicsRaw is List) {
      for (final item in topicsRaw) {
        if (item is String) topicsList.add(item);
      }
    }
    return Speaker(
      id: id,
      fullName: data['fullName'] as String? ?? data['name'] as String? ?? '',
      displayName: data['displayName'] as String?,
      title: data['title'] as String?,
      cluster: data['cluster'] as String?,
      photoUrl: data['photoUrl'] as String?,
      bio: data['bio'] as String?,
      yearsInCfc: _toInt(data['yearsInCfc']),
      familiesMentored: _toInt(data['familiesMentored']),
      talksGiven: _toInt(data['talksGiven']),
      location: data['location'] as String?,
      topics: topicsList,
      quote: data['quote'] as String?,
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      facebookUrl: data['facebookUrl'] as String?,
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
