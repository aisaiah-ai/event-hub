// ignore_for_file: avoid_print
/// Flutter entry point for seeding NLC registrants.
/// Run: flutter run -t lib/seed_main.dart -d macos --dart-define=ENV=dev -- <path-to-file>
///
/// Supports: .csv, .xlsx, .xls
/// PII (names, email, phone, etc.) is hashed before storage.

import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'src/tools/seed_nlc_registrants.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Env vars (macOS) or dart-define (web). String.fromEnvironment is compile-time.
  const seedFileDefine = String.fromEnvironment('SEED_FILE', defaultValue: '');
  const seedNoHashDefine = String.fromEnvironment('SEED_NO_HASH', defaultValue: '');

  var filePath = seedFileDefine.isNotEmpty ? seedFileDefine : null;
  if (filePath == null) {
    filePath = Platform.environment['SEED_FILE'];
  }
  if (filePath == null || filePath.isEmpty) {
    if (args.isNotEmpty) {
      filePath = args.first;
    } else {
      final seedInput = File('tools/seed_input.txt');
      if (await seedInput.exists()) {
        final lines = (await seedInput.readAsString())
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && !s.startsWith('#'));
        filePath = lines.isNotEmpty ? lines.first : null;
      }
    }
  }

  if (filePath == null || filePath.isEmpty) {
    print('Usage:');
    print('  flutter run -t lib/seed_main.dart -d macos --dart-define=ENV=dev -- <path-to-file>');
    print('  SEED_FILE=/path/to/file flutter run -t lib/seed_main.dart -d macos --dart-define=ENV=dev');
    print('');
    print('  SEED_NO_HASH=1 or --dart-define=SEED_NO_HASH=1  Skip PII hashing');
    print('');
    print('Supports: .csv, .xlsx, .xls');
    print('Target: event-hub-dev, events/nlc-2026/registrants');
    exit(1);
  }

  final noHash = seedNoHashDefine == '1' || seedNoHashDefine == 'true'
      || (Platform.environment['SEED_NO_HASH'] ?? '').toLowerCase() == '1';

  const clearFirstDefine = String.fromEnvironment('SEED_CLEAR_FIRST', defaultValue: '');
  final clearFirst = clearFirstDefine == '1' || clearFirstDefine == 'true'
      || (Platform.environment['SEED_CLEAR_FIRST'] ?? '').toLowerCase() == '1'
      || (filePath?.contains('nlc_main_clean') ?? false);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (!e.code.contains('duplicate')) rethrow;
    // Native (iOS/macOS) auto-initializes from plist; app already exists
  }

  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  } catch (e) {
    print('Warning: App Check activation failed: $e');
  }

  try {
    final result = await runSeed(filePath, hashPii: !noHash, clearFirst: clearFirst);
    print('');
    print('Done. Imported: ${result.imported}, Skipped: ${result.skipped}');
    if (result.sessionRegistrationsWritten > 0) {
      print('Session registrations: ${result.sessionRegistrationsWritten}');
    }
    print('Registrants: events/nlc-2026/registrants (event-hub-dev)');
  } catch (e, st) {
    print('Error: $e');
    print(st);
    exit(1);
  }

  exit(0);
}
