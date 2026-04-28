// lib/service/location_service.dart

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fayow/model/poi_models.dart';
import 'package:fayow/repository/poi_repository.dart';
import 'package:fayow/location/commune_manager.dart';

class LocationService {
  static const double _seuilProximite = 20.0; // mètres
  static const Duration _intervalleLocalisation = Duration(seconds: 3);

  final PoiRepository _poiRepository = PoiRepository();
  final FlutterTts _tts = FlutterTts();
  final CommuneManager _communeManager = CommuneManager();

  // État interne
  List<PoiData> _pois = [];
  final Set<String> _poisAnnonces = {};
  final Set<String> _poisLus = {};
  bool _actif = false;
  bool _ttsReady = false;

  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<List<DocumentSnapshot>>? _firestoreSubscription;

  // Callbacks vers l'UI
  void Function(Position position)? onPositionChanged;
  void Function(PointInteret poi)? onPoiProche;
  void Function(String commune)? onCommuneChanged;

  // --- Démarrage / Arrêt ---

  Future<void> demarrer() async {
    if (_actif) return;
    _actif = true;

    await _initialiserTts();
    await _communeManager.initialiserTts();
    await _chargerPois();
    _ecouterFirestore();
    _demarrerLocalisation();
  }

  void arreter() {
    _actif = false;
    _locationSubscription?.cancel();
    _firestoreSubscription?.cancel();
    _tts.stop();
    _communeManager.shutdown();
  }

  void reinitialiserSession() {
    _poisAnnonces.clear();
    _communeManager.reinitialiser();
  }

  // --- TTS ---

  Future<void> _initialiserTts() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(0.9); // Voix légèrement masculine

    final voices = await _tts.getVoices as List?;
    if (voices != null) {
      final voixMasculine = voices.firstWhere(
        (v) =>
            v['locale'] == 'fr-FR' &&
            (v['name'] as String).toLowerCase().contains('male'),
        orElse: () => null,
      );
      if (voixMasculine != null) {
        await _tts.setVoice({
          'name': voixMasculine['name'],
          'locale': 'fr-FR',
        });
      }
    }
    _ttsReady = true;
  }

  Future<void> _annoncer(String message) async {
    if (!_ttsReady) return;
    await _tts.speak(message);
  }

  // --- Chargement des POIs ---

  Future<void> _chargerPois() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('pointsInteret')
        .get();

    _pois = snapshot.docs
        .where((doc) {
          final data = doc.data();
          final status = poiStatusFromFirestore(
            data['approved'] as bool?,
            data['status'] as String?,
          );
          if (status == PoiStatus.validated) return true;
          if (status == PoiStatus.initiated && data['creatorUid'] == uid) {
            return true;
          }
          return false;
        })
        .map((doc) {
          final data = doc.data();
          return PoiData(
            latitude: (data['latitude'] as num).toDouble(),
            longitude: (data['longitude'] as num).toDouble(),
            message: data['message'] as String? ?? '',
            status: poiStatusFromFirestore(
              data['approved'] as bool?,
              data['status'] as String?,
            ),
            creatorUid: data['creatorUid'] as String?,
          );
        })
        .toList();
  }

  // --- Écoute Firestore en temps réel ---

  void _ecouterFirestore() {
    FirebaseFirestore.instance
        .collection('pointsInteret')
        .snapshots()
        .listen((_) => _chargerPois());
  }

  // --- Localisation ---

  Future<void> _demarrerLocalisation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: settings)
            .listen(_onPosition);
  }

  void _onPosition(Position position) {
    onPositionChanged?.call(position);
    _verifierProximite(position);
    _verifierCommune(position);
  }

  // --- Proximité POI ---

  void _verifierProximite(Position position) {
    for (final poi in _pois) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        poi.latitude,
        poi.longitude,
      );

      final cle = '${poi.latitude}_${poi.longitude}';
      if (distance <= _seuilProximite && !_poisAnnonces.contains(cle)) {
        _poisAnnonces.add(cle);
        _annoncer(poi.message);

        // Notifie l'UI
        onPoiProche?.call(PointInteret(
          id: cle,
          latitude: poi.latitude,
          longitude: poi.longitude,
          message: poi.message,
          status: poi.status,
          creatorUid: poi.creatorUid,
        ));
      }
    }
  }

  // --- Vérification de commune ---

  Future<void> _verifierCommune(Position position) async {
    final pois = _pois
        .map((p) => PointInteret(
              id: '${p.latitude}_${p.longitude}',
              latitude: p.latitude,
              longitude: p.longitude,
              message: p.message,
              status: p.status,
              creatorUid: p.creatorUid,
            ))
        .toList();

    await _communeManager.verifierCommune(
      latitude: position.latitude,
      longitude: position.longitude,
      tousLesPois: pois,
    );
  }

  // --- Marquer comme lu ---

  Future<void> marquerLu(String poiId) async {
    _poisLus.add(poiId);
    _communeManager.marquerLu(poiId);
    await _poiRepository.markAsRead(poiId);
  }

  // --- Getters ---

  bool get estActif => _actif;
  List<PoiData> get pois => List.unmodifiable(_pois);
}