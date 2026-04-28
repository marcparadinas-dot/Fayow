// lib/map_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fayow/auth/auth_manager.dart';
import 'package:fayow/model/poi_models.dart';
import 'package:fayow/repository/poi_repository.dart';
import 'package:fayow/service/location_service.dart';
import 'package:fayow/ui/map/map_manager.dart';
import 'package:fayow/ui/permission_manager.dart';

class MapScreen extends StatefulWidget {
  final AuthManager authManager;

  const MapScreen({super.key, required this.authManager});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapManager _mapManager = MapManager();
  final LocationService _locationService = LocationService();
  final PermissionManager _permissionManager = PermissionManager();
  final PoiRepository _poiRepository = PoiRepository();

  List<PointInteret> _pois = [];
  bool _modeParcoursActif = false;
  PointInteret? _poiSelectionne;

  @override
  void initState() {
    super.initState();

    _mapManager.isModerator = widget.authManager.isModerator();
    _mapManager.addListener(() => setState(() {}));

    // Callbacks LocationService
    _locationService.onPositionChanged = (position) {
      _mapManager.mettreAJourPosition(
          LatLng(position.latitude, position.longitude));
      if (!_modeParcoursActif) _mapManager.centrerSurUtilisateur();
    };
    _locationService.onPoiProche = (poi) => _afficherDialogLecture(poi);

    // Callbacks MapManager
    _mapManager.onPoiTapped = (poi) => _afficherDialogPoi(poi);
    _mapManager.onPoiDeplace = (poi, position) =>
        _confirmerDeplacement(poi, position);

    _permissionManager.onAllPermissionsGranted = _demarrerService;
    _permissionManager.onBackgroundPermissionDenied = _demarrerService;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _permissionManager.demanderPermissions(context);
    });

    _chargerPois();
  }

  @override
  void dispose() {
    _locationService.arreter();
    _mapManager.dispose();
    super.dispose();
  }

  // --- Chargement ---

  Future<void> _chargerPois() async {
    final pois = await _poiRepository.loadAllPois();
    setState(() => _pois = pois);
  }

  void _demarrerService() => _locationService.demarrer();

  // --- Dialogs POI ---

  void _afficherDialogPoi(PointInteret poi) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Point d\'intérêt'),
        content: Text(poi.message),
        actions: [
          if (poi.creatorUid == widget.authManager.currentUser?.uid &&
              poi.status == PoiStatus.initiated) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _afficherDialogEdition(poi);
              },
              child: const Text('Modifier'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _proposerPoi(poi);
              },
              child: const Text('Proposer'),
            ),
          ],
          if (widget.authManager.isModerator() &&
              poi.status == PoiStatus.proposed) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _validerPoi(poi);
              },
              child: const Text('Valider'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _supprimerPoi(poi);
              },
              child: const Text('Refuser'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _afficherDialogLecture(PointInteret poi) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Point d\'intérêt à proximité'),
        content: Text(poi.message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _locationService.marquerLu(poi.id);
              _mapManager.marquerLu(poi.id);
            },
            child: const Text('Marquer comme lu'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _afficherDialogEdition(PointInteret poi) {
    final controller = TextEditingController(text: poi.message);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le point d\'intérêt'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Message',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              await _poiRepository.updatePoi(poi.id,
                  message: controller.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              _chargerPois();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _afficherDialogAjout(LatLng position) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter un point d\'intérêt'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Description',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final uid = widget.authManager.currentUser?.uid;
              if (uid == null) return;
              await _poiRepository.createPoi(
                latitude: position.latitude,
                longitude: position.longitude,
                message: controller.text.trim(),
                creatorUid: uid,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _chargerPois();
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  // --- Modération ---

  Future<void> _proposerPoi(PointInteret poi) async {
    await _poiRepository.updatePoi(poi.id, status: PoiStatus.proposed);
    _chargerPois();
  }

  Future<void> _validerPoi(PointInteret poi) async {
    await _poiRepository.updatePoi(poi.id, status: PoiStatus.validated);
    _chargerPois();
  }

  Future<void> _supprimerPoi(PointInteret poi) async {
    await _poiRepository.deletePoi(poi.id);
    _chargerPois();
  }

  // --- Déplacement POI ---

  Future<void> _confirmerDeplacement(PointInteret poi, LatLng position) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déplacer le point ?'),
        content: const Text('Confirmer le déplacement de ce point d\'intérêt ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _poiRepository.updatePoi(
        poi.id,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _chargerPois();
    } else {
      _mapManager.annulerDeplacement();
    }
  }



  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FaYoW'),
        actions: [
          // Mode parcourir
          IconButton(
            icon: Icon(_modeParcoursActif
                ? Icons.explore
                : Icons.explore_outlined),
            tooltip: 'Mode parcourir',
            onPressed: () {
              setState(() => _modeParcoursActif = !_modeParcoursActif);
              _mapManager.setMode(_modeParcoursActif
                  ? MapMode.parcourir
                  : MapMode.normal);
              if (!_modeParcoursActif) {
                _locationService.reinitialiserSession();
              }
            },
          ),
          // Déconnexion
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () async {
              _locationService.arreter();
              await widget.authManager.signOut();
            },
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapManager.mapController,
        options: MapOptions(
          initialCenter: const LatLng(46.5, 2.5), // Centre de la France
          initialZoom: 6,
          onTap: (_, position) {
            if (_mapManager.mode == MapMode.normal) {
              _afficherDialogAjout(position);
            }
          },
        ),
        children: [
          _mapManager.tileLayer,
          CircleLayer(circles: _mapManager.buildPoiCircles(_pois)),
          MarkerLayer(markers: [
            ..._mapManager.buildPoiMarkers(_pois),
            ..._mapManager.buildUserMarker(),
          ]),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mapManager.centrerSurUtilisateur,
        tooltip: 'Ma position',
        child: const Icon(Icons.my_location),
      ),
    );
  }
}