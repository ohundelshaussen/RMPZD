const colombiaDepartments = ['La Guajira', 'Cesar'];

const municipalitiesByDepartment = <String, List<String>>{
  'La Guajira': [
    'Riohacha',
    'Uribia',
    'Manaure',
    'Maicao',
    'San Juan del Cesar',
    'Dibulla',
    'Fonseca',
    'Albania',
  ],
  'Cesar': [
    'Valledupar',
    'Pueblo Bello',
    'Agustín Codazzi',
    'La Paz',
    'Aguachica',
    'Bosconia',
    'Curumaní',
  ],
};

/// Verified real urban center coordinates for all supported
/// municipalities in La Guajira and Cesar (2026 OSM/REPS audit).
const municipalityCoordinates = <String, ({double lat, double lng})>{
  'Riohacha': (lat: 11.54494, lng: -72.91505),
  'Uribia': (lat: 11.71486, lng: -72.26578),
  'Manaure': (lat: 11.77711, lng: -72.44694),
  'Maicao': (lat: 11.37731, lng: -72.23876),
  'San Juan del Cesar': (lat: 10.77353, lng: -73.00192),
  'Dibulla': (lat: 11.27225, lng: -73.31144),
  'Fonseca': (lat: 10.89109, lng: -72.85186),
  'Albania': (lat: 11.1608, lng: -72.5922),
  'Valledupar': (lat: 10.4778, lng: -73.2446),
  'Pueblo Bello': (lat: 10.4161, lng: -73.5863),
  'Agustín Codazzi': (lat: 10.0355, lng: -73.2373),
  'La Paz': (lat: 10.3856, lng: -73.1686),
  'Aguachica': (lat: 8.3101, lng: -73.6238),
  'Bosconia': (lat: 9.9730, lng: -73.8861),
  'Curumaní': (lat: 9.1999, lng: -73.5432),
};

/// Normalizes territory names (case-insensitive, collapsed whitespace,
/// Spanish diacritics stripped).
String? normalizeLocationName(String? value) {
  final trimmed = value?.trim().toLowerCase();
  if (trimmed == null || trimmed.isEmpty) return null;
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  final buffer = StringBuffer();
  for (var i = 0; i < trimmed.length; i++) {
    final ch = trimmed[i];
    buffer.write(replacements[ch] ?? ch);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

({double lat, double lng})? coordinatesForMunicipality(String? municipality) {
  final target = normalizeLocationName(municipality);
  if (target == null) return null;
  for (final entry in municipalityCoordinates.entries) {
    if (normalizeLocationName(entry.key) == target) {
      return entry.value;
    }
  }
  return null;
}
