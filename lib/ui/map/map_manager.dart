// lib/ui/map/map_manager.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fayow/model/poi_models.dart';

enum MapMode { normal, parcourir }

class MapManager extends ChangeNotifier {
  final MapController mapController = MapController();

  MapMode _mode = MapMode.normal;
  MapMode get mode => _mode;

  LatLng? _positionUtilisateur;
  LatLng? get positionUtilisateur => _positionUtilisateur;

  // POI en cours de déplacement
  PointInteret? _poiEnDeplacement;
  LatLng? _positionOrigineDrag;
  LatLng? _positionDragActuelle;
  PointInteret? get poiEnDeplacement => _poiEnDeplacement;
  LatLng? get positionDragActuelle => _positionDragActuelle;

  // Cache des POIs lus
  final Set<String> _poisLus = {};

  bool isModerator = false;

  // Callbacks
  void Function(PointInteret poi)? onPoiTapped;
  void Function(PointInteret poi, LatLng nouvellePosition)? onPoiDeplace;

  // --- Mode ---

  void setMode(MapMode mode) {
    _mode = mode;
    notifyListeners();
  }

  // --- Position utilisateur ---

  void mettreAJourPosition(LatLng position) {
    _positionUtilisateur = position;
    notifyListeners();
  }

  void centrerSurUtilisateur() {
    if (_positionUtilisateur != null) {
      mapController.move(_positionUtilisateur!, mapController.camera.zoom);
    }
  }

  // --- POIs lus ---

  void marquerLu(String poiId) {
    _poisLus.add(poiId);
    notifyListeners();
  }

  bool estLu(String poiId) => _poisLus.contains(poiId);

  // --- Drag & Drop ---

  void demarrerDrag(PointInteret poi) {
    _poiEnDeplacement = poi;
    _positionOrigineDrag = LatLng(poi.latitude, poi.longitude);
    _positionDragActuelle = LatLng(poi.latitude, poi.longitude);
    notifyListeners();
  }

  void mettreAJourDrag(LatLng position) {
    _positionDragActuelle = position;
    notifyListeners();
  }

  void validerDeplacement() {
    if (_poiEnDeplacement != null && _positionDragActuelle != null) {
      onPoiDeplace?.call(_poiEnDeplacement!, _positionDragActuelle!);
    }
    _annulerDrag();
  }

  void _annulerDrag() {
    _poiEnDeplacement = null;
    _positionOrigineDrag = null;
    _positionDragActuelle = null;
    notifyListeners();
  }

  void annulerDeplacement() => _annulerDrag();

  // --- Couches de la carte ---

  /// Couche de tuiles OpenStreetMap
  TileLayer get tileLayer => TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.example.fayow',
      );

  /// Cercles des POIs
  List<CircleMarker> buildPoiCircles(List<PointInteret> pois) {
    final circles = <CircleMarker>[];

    for (final poi in pois) {
      if (!_estVisible(poi)) continue;

      final couleur = _couleurPoi(poi);
      circles.add(CircleMarker(
        point: LatLng(poi.latitude, poi.longitude),
        radius: 20,
        color: couleur.withOpacity(0.4),
        borderColor: couleur,
        borderStrokeWidth: 2,
      ));
    }

    // Fantôme de drag
    if (_positionDragActuelle != null) {
      circles.add(CircleMarker(
        point: _positionDragActuelle!,
        radius: 20,
        color: Colors.orange.withOpacity(0.3),
        borderColor: Colors.orange,
        borderStrokeWidth: 2,
      ));
    }

    return circles;
  }

  /// Marqueurs cliquables des POIs
  List<Marker> buildPoiMarkers(List<PointInteret> pois) {
    final markers = <Marker>[];

    for (final poi in pois) {
      if (!_estVisible(poi)) continue;
      if (!_estCliquable(poi)) continue;

      markers.add(Marker(
        point: LatLng(poi.latitude, poi.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => onPoiTapped?.call(poi),
          onLongPress: () {
            if (poi.status == PoiStatus.initiated) demarrerDrag(poi);
          },
          child: const SizedBox.expand(),
        ),
      ));
    }

    return markers;
  }

  /// Marqueur de position utilisateur
  List<Marker> buildUserMarker() {
    if (_positionUtilisateur == null) return [];
    return [
      Marker(
        point: _positionUtilisateur!,
        width: 20,
        height: 20,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4),
            ],
          ),
        ),
      ),
    ];
  }

  // --- Utilitaires ---

  Color _couleurPoi(PointInteret poi) {
    if (isModerator &&
        poi.status == PoiStatus.validated &&
        !estLu(poi.id)) {
      return Colors.purple;
    }
    switch (poi.status) {
      case PoiStatus.validated:
        return Colors.green;
      case PoiStatus.proposed:
        return Colors.orange;
      case PoiStatus.initiated:
        return Colors.red;
    }
  }

  bool _estVisible(PointInteret poi) {
    if (_poiEnDeplacement?.id == poi.id) return false;
    switch (_mode) {
      case MapMode.normal:
        return true;
      case MapMode.parcourir:
        return poi.status == PoiStatus.validated ||
            poi.status == PoiStatus.proposed;
    }
  }

  bool _estCliquable(PointInteret poi) {
    switch (_mode) {
      case MapMode.normal:
        return true;
      case MapMode.parcourir:
        return poi.status == PoiStatus.validated;
    }
  }
}