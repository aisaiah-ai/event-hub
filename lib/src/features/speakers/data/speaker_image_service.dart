import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

/// Handles upload of a speaker profile photo to Firebase Storage and updates
/// the speaker document's [photoUrl] field in Firestore.
///
/// Uses [XFile] from image_picker so it works on Flutter web, iOS, and Android
/// without importing dart:io. Bytes are read with [XFile.readAsBytes] and
/// uploaded via [Reference.putData].
///
/// Storage path: events/{eventId}/speakers/{speakerId}/profile{ext}
/// Firestore field: events/{eventId}/speakers/{speakerId}.photoUrl
class SpeakerImageService {
  SpeakerImageService({FirebaseStorage? storage, FirebaseFirestore? firestore})
    : _storage = storage ?? FirebaseStorage.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;

  static const int _maxBytes = 2 * 1024 * 1024; // 2 MB

  static const _allowedExtensions = <String>['.jpg', '.jpeg', '.png', '.webp'];

  static String? _contentType(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return null;
    }
  }

  /// Uploads [xfile] as the profile photo for [speakerId] under [eventId].
  ///
  /// Validates file type and size, uploads to Firebase Storage, then writes
  /// the resulting download URL to Firestore. Returns the download URL.
  ///
  /// Throws [SpeakerImageUploadException] for validation or upload failures.
  Future<String> uploadSpeakerPhoto({
    required String eventId,
    required String speakerId,
    required XFile xfile,
  }) async {
    // ── 1. Validate extension ──────────────────────────────────────────────
    // Use the filename (not the path) so this works on web where xfile.path
    // is a blob URI, not a real file-system path.
    final ext = p.extension(xfile.name).toLowerCase();
    if (!_allowedExtensions.contains(ext)) {
      throw SpeakerImageUploadException(
        'Unsupported file type "$ext". Allowed: jpg, jpeg, png, webp.',
      );
    }

    // ── 2. Read bytes (cross-platform; no dart:io File) ───────────────────
    final bytes = await xfile.readAsBytes();

    // ── 3. Validate size ──────────────────────────────────────────────────
    if (bytes.length > _maxBytes) {
      final sizeMb = (bytes.length / 1024 / 1024).toStringAsFixed(1);
      throw SpeakerImageUploadException(
        'File is too large ($sizeMb MB). Maximum allowed size is 2 MB.',
      );
    }

    // ── 4. Build storage reference ────────────────────────────────────────
    // Path: events/{eventId}/speakers/{speakerId}/profile{ext}
    // Using a fixed filename per speaker means re-uploading simply overwrites
    // the previous file with no orphaned storage objects.
    final ref = _storage
        .ref()
        .child('events')
        .child(eventId)
        .child('speakers')
        .child(speakerId)
        .child('profile$ext');

    // ── 5. Upload ─────────────────────────────────────────────────────────
    try {
      final contentType = _contentType(ext);
      await ref.putData(
        bytes,
        contentType != null ? SettableMetadata(contentType: contentType) : null,
      );
    } on FirebaseException catch (e) {
      throw SpeakerImageUploadException(
        'Storage upload failed: ${e.message ?? e.code}',
      );
    }

    // ── 6. Get download URL ───────────────────────────────────────────────
    final String downloadUrl;
    try {
      downloadUrl = await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw SpeakerImageUploadException(
        'Could not retrieve download URL: ${e.message ?? e.code}',
      );
    }

    // ── 7. Persist URL to Firestore ───────────────────────────────────────
    try {
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('speakers')
          .doc(speakerId)
          .update({
            'photoUrl': downloadUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } on FirebaseException catch (e) {
      // Upload succeeded but Firestore write failed. Surface the URL so the
      // caller can retry the Firestore write if needed.
      throw SpeakerImageUploadException(
        'Image uploaded but Firestore update failed: ${e.message ?? e.code}. '
        'photoUrl: $downloadUrl',
      );
    }

    return downloadUrl;
  }
}

/// Thrown by [SpeakerImageService] for validation or upload failures.
class SpeakerImageUploadException implements Exception {
  const SpeakerImageUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}
