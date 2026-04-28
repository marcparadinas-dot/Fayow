// lib/repository/poi_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fayow/model/poi_models.dart';

class PoiRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'pointsInteret';

  // --- Lecture ---

  Future<List<PointInteret>> loadAllPois() async {
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs.map((doc) => _fromDoc(doc)).toList();
  }

  Stream<List<PointInteret>> poisStream() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => _fromDoc(doc)).toList());
  }

  Future<List<PointInteret>> loadPoisForUser(String uid) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('creatorUid', isEqualTo: uid)
        .get();
    return snapshot.docs.map((doc) => _fromDoc(doc)).toList();
  }

  Future<List<PointInteret>> loadPendingPois() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'proposed')
        .get();
    return snapshot.docs.map((doc) => _fromDoc(doc)).toList();
  }

  // --- Écriture ---

  Future<String> createPoi({
    required double latitude,
    required double longitude,
    required String message,
    required String creatorUid,
    PoiStatus status = PoiStatus.initiated,
  }) async {
    final doc = await _firestore.collection(_collection).add({
      'latitude': latitude,
      'longitude': longitude,
      'message': message,
      'creatorUid': creatorUid,
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
    return doc.id;
  }

  Future<void> updatePoi(
    String id, {
    String? message,
    PoiStatus? status,
    double? latitude,
    double? longitude,
  }) async {
    final data = <String, dynamic>{};
    if (message != null) data['message'] = message;
    if (status != null) data['status'] = status.name;
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    if (data.isEmpty) return;
    await _firestore.collection(_collection).doc(id).update(data);
  }

  Future<void> deletePoi(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Future<void> markAsRead(String id) async {
    await _firestore.collection(_collection).doc(id).update({'isRead': true});
  }

  // --- Conversion Firestore → modèle ---

  PointInteret _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PointInteret(
      id: doc.id,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      message: data['message'] as String? ?? '',
      status: poiStatusFromFirestore(
        data['approved'] as bool?,
        data['status'] as String?,
      ),
      creatorUid: data['creatorUid'] as String?,
    );
  }
}