import 'package:latlong2/latlong.dart';

enum PoiStatus { initiated, proposed, validated }

class PointInteret {
  final String id;
  final LatLng position;
  final String message;
  final PoiStatus status;
  final String creatorUid;

  PointInteret({
    required this.id,
    required this.position,
    required this.message,
    required this.status,
    required this.creatorUid,
  });

  factory PointInteret.fromFirestore(String id, Map<String, dynamic> data) {
    return PointInteret(
      id: id,
      position: LatLng(
        (data['lat'] as num).toDouble(),
        (data['lng'] as num).toDouble(),
      ),
      message: data['message'] ?? '',
      status: PoiStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'initiated'),
        orElse: () => PoiStatus.initiated,
      ),
      creatorUid: data['creatorUid'] ?? '',
    );
  }

  PointInteret copyWith({LatLng? position}) {
    return PointInteret(
      id: id,
      position: position ?? this.position,
      message: message,
      status: status,
      creatorUid: creatorUid,
    );
  }
}