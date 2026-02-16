// ignore_for_file: avoid_print
/// DEPRECATED: Use Flutter-based seed instead.
///
/// Run: SEED_FILE=/path/to/file flutter run -t lib/seed_main.dart -d macos --dart-define=ENV=dev
///
/// See tools/SEED_README.md for full instructions.
import 'dart:io';

void main(List<String> args) {
  print('Use Flutter-based seed instead:');
  print('');
  print('  SEED_FILE="/path/to/file.xlsx" flutter run -t lib/seed_main.dart -d macos --dart-define=ENV=dev');
  print('');
  print('See tools/SEED_README.md for details.');
  exit(1);
}
