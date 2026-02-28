/// Venue for an event (name + full address for display and maps).
class Venue {
  const Venue({
    required this.name,
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
  });

  final String name;
  final String street;
  final String city;
  final String state;
  final String zip;

  /// Full address line for maps: "street, city, state zip"
  String get fullAddress {
    final parts = <String>[];
    if (street.isNotEmpty) parts.add(street);
    if (city.isNotEmpty) parts.add(city);
    if (state.isNotEmpty) parts.add(state);
    if (zip.isNotEmpty) parts.add(zip);
    return parts.join(', ');
  }

  static Venue? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final name = map['name'] as String? ?? '';
    final street = map['street'] as String? ?? '';
    final city = map['city'] as String? ?? '';
    final state = map['state'] as String? ?? '';
    final zip = map['zip'] as String? ?? '';
    if (name.isEmpty && street.isEmpty && city.isEmpty && state.isEmpty && zip.isEmpty) {
      return null;
    }
    return Venue(name: name, street: street, city: city, state: state, zip: zip);
  }
}
