/// Source of registrant record.
enum RegistrantSource { import, registration, manual, rsvp }

extension RegistrantSourceX on RegistrantSource {
  static RegistrantSource fromString(String value) {
    switch (value.toUpperCase()) {
      case 'IMPORT':
        return RegistrantSource.import;
      case 'REGISTRATION':
        return RegistrantSource.registration;
      case 'MANUAL':
        return RegistrantSource.manual;
      case 'RSVP':
        return RegistrantSource.rsvp;
      default:
        return RegistrantSource.registration;
    }
  }

  String get name {
    switch (this) {
      case RegistrantSource.import:
        return 'IMPORT';
      case RegistrantSource.registration:
        return 'REGISTRATION';
      case RegistrantSource.manual:
        return 'MANUAL';
      case RegistrantSource.rsvp:
        return 'RSVP';
    }
  }
}
