/// Check-in screen state.
class CheckinState {
  const CheckinState({this.isOffline = false, this.lastResult});

  final bool isOffline;
  final CheckinResult? lastResult;

  CheckinState copyWith({bool? isOffline, CheckinResult? lastResult}) {
    return CheckinState(
      isOffline: isOffline ?? this.isOffline,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

/// Result of a check-in attempt.
class CheckinResult {
  const CheckinResult({
    required this.name,
    this.role,
    this.chapter,
    required this.timestamp,
    required this.status,
    this.photoUrl,
    this.message,
  });

  final String name;
  final String? role;
  final String? chapter;
  final DateTime timestamp;
  final CheckinStatus status;
  final String? photoUrl;
  final String? message;
}

enum CheckinStatus { success, duplicate, error }
