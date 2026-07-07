enum IncidentType {
  harassment('HARASSMENT', 'Harassment'),
  poorLighting('OTHER', 'Poor lighting'),
  unsafeStreet('OTHER', 'Unsafe street'),
  desertedArea('OTHER', 'Deserted area'),
  suspiciousActivity('STALKING', 'Suspicious activity');

  const IncidentType(this.apiValue, this.label);

  final String apiValue;
  final String label;
}
