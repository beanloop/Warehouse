part of warehouse;

/// A geographical point denoted by degrees north and degrees east
class GeoPoint {
  /// Degrees north from the equator.
  ///
  /// Points located to the south of the equator have negative values,
  /// while points located to the north of it have positive values.
  final num latitude;

  /// Degrees east from the prime meridian.
  ///
  /// Points located to the west of the prime meridian have negative values,
  /// while points located to the east of it have positive values.
  final num longitude;

  const GeoPoint(this.latitude, this.longitude);

  toString() => 'Latitude: $latitude, Longitude: $longitude';

  int get hashCode => quiver.hash2(latitude.hashCode, longitude.hashCode);
  operator ==(other) {
    if (other is! GeoPoint) return false;

    return latitude == other.latitude && longitude == other.longitude;
  }
}
