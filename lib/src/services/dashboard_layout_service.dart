import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/firestore_config.dart';

/// Section IDs for dashboard. Order in list = display order.
/// Default: metric tiles (total registrants, etc.) → session leaderboard → first 3 → top 5 regions → check-in trend.
const List<String> kDefaultDashboardOrder = [
  'metrics',
  'sessionLeaderboard',
  'first3',
  'top5',
  'graph',
];

/// Section IDs for wallboard. Metrics, Leaderboard, Trend only.
const List<String> kDefaultWallboardOrder = [
  'metrics',
  'leaderboard',
  'graph',
];

/// Human-readable labels for section IDs.
const Map<String, String> kDashboardSectionLabels = {
  'metrics': 'Metric Tiles',
  'graph': 'Check-In Trend',
  'sessionLeaderboard': 'Session Leaderboard',
  'top5': 'Top 5 Regions & Ministries',
  'first3': 'First 3 Registrations & Check-Ins',
};

const Map<String, String> kWallboardSectionLabels = {
  'metrics': 'Metric Tiles',
  'leaderboard': 'Session Leaderboard',
  'graph': 'Check-In Trend',
};

const String _prefsKeyPrefix = 'layout_order_';

/// Loads and saves layout order for dashboard and wallboard.
/// Uses Firestore when staff auth; falls back to SharedPreferences when permission-denied.
class DashboardLayoutService {
  DashboardLayoutService({
    FirebaseFirestore? firestore,
    SharedPreferences? sharedPreferences,
  })  : _firestore = firestore ?? FirestoreConfig.instance,
        _sharedPrefs = sharedPreferences;

  final FirebaseFirestore _firestore;
  SharedPreferences? _sharedPrefs;

  Future<SharedPreferences> get _prefs async =>
      _sharedPrefs ??= await SharedPreferences.getInstance();

  String _settingsPath(String eventId) => 'events/$eventId/settings';
  String _prefsDashboardKey(String eventId) => '${_prefsKeyPrefix}dashboard_$eventId';
  String _prefsWallboardKey(String eventId) => '${_prefsKeyPrefix}wallboard_$eventId';

  bool _isPermissionDenied(Object e) {
    return e.toString().contains('permission-denied') ||
        (e is FirebaseException && e.code == 'permission-denied');
  }

  /// Read dashboard order from SharedPreferences (fallback when Firestore fails).
  Future<List<String>> _getLocalDashboardOrder(String eventId) async {
    try {
      final prefs = await _prefs;
      final json = prefs.getString(_prefsDashboardKey(eventId));
      if (json == null || json.isEmpty) return List.from(kDefaultDashboardOrder);
      final list = json.split(',');
      return _validatedOrder(list, kDefaultDashboardOrder);
    } catch (_) {
      return List.from(kDefaultDashboardOrder);
    }
  }

  /// Read wallboard order from SharedPreferences.
  Future<List<String>> _getLocalWallboardOrder(String eventId) async {
    try {
      final prefs = await _prefs;
      final json = prefs.getString(_prefsWallboardKey(eventId));
      if (json == null || json.isEmpty) return List.from(kDefaultWallboardOrder);
      final list = json.split(',');
      return _validatedOrder(list, kDefaultWallboardOrder);
    } catch (_) {
      return List.from(kDefaultWallboardOrder);
    }
  }

  /// Save dashboard order to SharedPreferences (fallback).
  Future<void> _setLocalDashboardOrder(String eventId, List<String> order) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(_prefsDashboardKey(eventId), order.join(','));
    } catch (_) {}
  }

  /// Save wallboard order to SharedPreferences (fallback).
  Future<void> _setLocalWallboardOrder(String eventId, List<String> order) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(_prefsWallboardKey(eventId), order.join(','));
    } catch (_) {}
  }

  /// Read dashboard section order. Returns default if not set.
  Future<List<String>> getDashboardOrder(String eventId) async {
    try {
      final snap = await _firestore
          .doc('${_settingsPath(eventId)}/layouts')
          .get();
      final data = snap.data();
      final list = data?['dashboardOrder'] as List<dynamic>?;
      if (list == null || list.isEmpty) {
        return _getLocalDashboardOrder(eventId);
      }
      return _validatedOrder(
        list.map((e) => e.toString()).toList(),
        kDefaultDashboardOrder,
      );
    } catch (e) {
      if (_isPermissionDenied(e)) {
        return _getLocalDashboardOrder(eventId);
      }
      rethrow;
    }
  }

  /// Read wallboard section order. Returns default if not set.
  Future<List<String>> getWallboardOrder(String eventId) async {
    try {
      final snap = await _firestore
          .doc('${_settingsPath(eventId)}/layouts')
          .get();
      final data = snap.data();
      final list = data?['wallboardOrder'] as List<dynamic>?;
      if (list == null || list.isEmpty) {
        return _getLocalWallboardOrder(eventId);
      }
      return _validatedOrder(
        list.map((e) => e.toString()).toList(),
        kDefaultWallboardOrder,
      );
    } catch (e) {
      if (_isPermissionDenied(e)) {
        return _getLocalWallboardOrder(eventId);
      }
      rethrow;
    }
  }

  /// Stream of dashboard order. Falls back to SharedPreferences when Firestore permission-denied.
  Stream<List<String>> watchDashboardOrder(String eventId) {
    late StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> sub;
    final controller = StreamController<List<String>>(
      onCancel: () => sub.cancel(),
    );
    sub = _firestore
        .doc('${_settingsPath(eventId)}/layouts')
        .snapshots()
        .listen(
          (snap) {
            if (!controller.isClosed) {
              final data = snap.data();
              final list = data?['dashboardOrder'] as List<dynamic>?;
              if (list == null || list.isEmpty) {
                controller.add(List.from(kDefaultDashboardOrder));
              } else {
                controller.add(_validatedOrder(
                  list.map((e) => e.toString()).toList(),
                  kDefaultDashboardOrder,
                ));
              }
            }
          },
          onError: (Object e, StackTrace st) async {
            if (_isPermissionDenied(e)) {
              controller.add(await _getLocalDashboardOrder(eventId));
            } else {
              controller.addError(e, st);
            }
            await controller.close();
          },
        );
    return controller.stream;
  }

  /// Stream of wallboard order. Falls back to SharedPreferences when Firestore permission-denied.
  Stream<List<String>> watchWallboardOrder(String eventId) {
    late StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> sub;
    final controller = StreamController<List<String>>(
      onCancel: () => sub.cancel(),
    );
    sub = _firestore
        .doc('${_settingsPath(eventId)}/layouts')
        .snapshots()
        .listen(
          (snap) {
            if (!controller.isClosed) {
              final data = snap.data();
              final list = data?['wallboardOrder'] as List<dynamic>?;
              if (list == null || list.isEmpty) {
                controller.add(List.from(kDefaultWallboardOrder));
              } else {
                controller.add(_validatedOrder(
                  list.map((e) => e.toString()).toList(),
                  kDefaultWallboardOrder,
                ));
              }
            }
          },
          onError: (Object e, StackTrace st) async {
            if (_isPermissionDenied(e)) {
              controller.add(await _getLocalWallboardOrder(eventId));
            } else {
              controller.addError(e, st);
            }
            await controller.close();
          },
        );
    return controller.stream;
  }

  /// Save dashboard order. Uses Firestore; falls back to SharedPreferences on permission-denied.
  Future<void> saveDashboardOrder(String eventId, List<String> order) async {
    try {
      await _firestore.doc('${_settingsPath(eventId)}/layouts').set({
        'dashboardOrder': order,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (_isPermissionDenied(e)) {
        await _setLocalDashboardOrder(eventId, order);
      } else {
        rethrow;
      }
    }
  }

  /// Save wallboard order. Uses Firestore; falls back to SharedPreferences on permission-denied.
  Future<void> saveWallboardOrder(String eventId, List<String> order) async {
    try {
      await _firestore.doc('${_settingsPath(eventId)}/layouts').set({
        'wallboardOrder': order,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (_isPermissionDenied(e)) {
        await _setLocalWallboardOrder(eventId, order);
      } else {
        rethrow;
      }
    }
  }

  List<String> _validatedOrder(List<String> order, List<String> defaultOrder) {
    final valid = defaultOrder.toSet();
    final result = order.where((id) => valid.contains(id)).toList();
    for (final id in defaultOrder) {
      if (!result.contains(id)) result.add(id);
    }
    return result;
  }
}
