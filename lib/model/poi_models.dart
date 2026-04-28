// lib/model/poi_models.dart

// --- Enum ---

enum PoiStatus {
  initiated,  // Brouillon personnel
  proposed,   // Proposé à la modération
  validated,  // Validé par un modérateur
}

// --- Data classes ---

class PointInteret {
  final String id;
  final double latitude;
  final double longitude;
  final String message;
  final PoiStatus status;
  final String? creatorUid;

  const PointInteret({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.message,
    this.status = PoiStatus.validated,
    this.creatorUid,
  });
}

// Utilisé dans LocationService pour le cache mémoire
class PoiData {
  final double latitude;
  final double longitude;
  final String message;
  final PoiStatus status;
  final String? creatorUid;

  const PoiData({
    required this.latitude,
    required this.longitude,
    required this.message,
    this.status = PoiStatus.validated,
    this.creatorUid,
  });
}

class PendingPoi {
  final String id;
  final String message;

  const PendingPoi({
    required this.id,
    required this.message,
  });
}

// --- Fonction utilitaire ---

PoiStatus poiStatusFromFirestore(bool? approved, String? status) {
  switch (status) {
    case 'initiated':
      return PoiStatus.initiated;
    case 'proposed':
      return PoiStatus.proposed;
    case 'validated':
      return PoiStatus.validated;
    default:
      return (approved == true) ? PoiStatus.validated : PoiStatus.proposed;
  }
}