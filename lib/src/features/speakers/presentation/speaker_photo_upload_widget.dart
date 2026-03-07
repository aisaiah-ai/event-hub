import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/speaker_image_service.dart';

/// Admin widget for uploading or replacing a speaker's profile photo.
///
/// Drop-in anywhere an event + speaker ID is available:
///
/// ```dart
/// SpeakerPhotoUploadWidget(
///   eventId: 'march-assembly',
///   speakerId: 'rommel-dolar',
///   currentPhotoUrl: speaker.photoUrl,
///   onUploaded: (url) => setState(() => speaker = speaker.copyWith(photoUrl: url)),
/// )
/// ```
class SpeakerPhotoUploadWidget extends StatefulWidget {
  const SpeakerPhotoUploadWidget({
    super.key,
    required this.eventId,
    required this.speakerId,
    this.currentPhotoUrl,
    this.onUploaded,
  });

  final String eventId;
  final String speakerId;

  /// Current photo URL displayed as preview. Pass [Speaker.photoUrl].
  final String? currentPhotoUrl;

  /// Called with the new download URL after a successful upload.
  final void Function(String newUrl)? onUploaded;

  @override
  State<SpeakerPhotoUploadWidget> createState() =>
      _SpeakerPhotoUploadWidgetState();
}

class _SpeakerPhotoUploadWidgetState extends State<SpeakerPhotoUploadWidget> {
  // Lazy — FirebaseStorage.instance must not be called before Firebase.initializeApp.
  SpeakerImageService? _service;
  SpeakerImageService get _imageService => _service ??= SpeakerImageService();

  final _picker = ImagePicker();

  bool _uploading = false;
  String? _liveUrl; // updated optimistically after upload

  @override
  void initState() {
    super.initState();
    _liveUrl = widget.currentPhotoUrl;
  }

  Future<void> _pickAndUpload() async {
    // Opens the system file picker on web; gallery on mobile.
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      // image_picker compresses on native; on web the plugin handles it.
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (xfile == null) return; // user cancelled

    setState(() => _uploading = true);

    try {
      final url = await _imageService.uploadSpeakerPhoto(
        eventId: widget.eventId,
        speakerId: widget.speakerId,
        xfile: xfile,
      );
      if (mounted) {
        setState(() {
          _liveUrl = url;
          _uploading = false;
        });
        widget.onUploaded?.call(url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo uploaded successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on SpeakerImageUploadException catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Photo preview ──────────────────────────────────────────────────
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            _SpeakerPhotoPreview(photoUrl: _liveUrl, radius: 52),
            if (_uploading)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x88000000),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            if (!_uploading)
              GestureDetector(
                onTap: _pickAndUpload,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Upload button ──────────────────────────────────────────────────
        SizedBox(
          width: 220,
          child: OutlinedButton.icon(
            onPressed: _uploading ? null : _pickAndUpload,
            icon: _uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_rounded, size: 18),
            label: Text(_uploading ? 'Uploading…' : 'Upload Photo'),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'JPG · PNG · WebP  ·  Max 2 MB',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

// ─── Photo preview ─────────────────────────────────────────────────────────

class _SpeakerPhotoPreview extends StatelessWidget {
  const _SpeakerPhotoPreview({required this.photoUrl, this.radius = 40});

  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;

    // No photo — show placeholder initials circle
    if (url == null || url.isEmpty) {
      return _placeholder(radius);
    }

    // Bundled asset (local fallback — development only)
    if (url.startsWith('assets/')) {
      return SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: ClipOval(
          child: Image.asset(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholder(radius),
          ),
        ),
      );
    }

    // Firebase Storage / network URL — use CachedNetworkImage
    return CachedNetworkImage(
      imageUrl: url,
      imageBuilder: (context, imageProvider) =>
          CircleAvatar(radius: radius, backgroundImage: imageProvider),
      placeholder: (_, _) => CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      errorWidget: (_, _, _) => _placeholder(radius),
    );
  }

  static Widget _placeholder(double radius) => CircleAvatar(
    radius: radius,
    backgroundColor: Colors.grey.shade200,
    child: Icon(
      Icons.person_rounded,
      size: radius * 0.85,
      color: Colors.grey.shade500,
    ),
  );
}
