// lib/location/commune_manager.dart

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:fayow/model/poi_models.dart';

class CommuneManager {
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;

  String? _communeActuelle;
  List<List<double>>? _polygoneActuel; // Liste de [lon, lat]

  // IDs des POIs déjà lus
  final Set<String> _poisLus = {};

  // --- Initialisation ---

  Future<void> initialiserTts() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.2); // Voix légèrement féminine

    final voices = await _tts.getVoices as List?;
    if (voices != null) {
      final voixFeminine = voices.firstWhere(
        (v) =>
            v['locale'] == 'fr-FR' &&
            (v['name'] as String).toLowerCase().contains('female'),
        orElse: () => null,
      );
      if (voixFeminine != null) {
        await _tts.setVoice({'name': voixFeminine['name'], 'locale': 'fr-FR'});
      }
    }
    _ttsReady = true;
  }

  void shutdown() {
    _tts.stop();
    _ttsReady = false;
  }

  void reinitialiser() {
    _communeActuelle = null;
    _polygoneActuel = null;
    _poisLus.clear();
  }

  void marquerLu(String poiId) => _poisLus.add(poiId);

  // --- Vérification de commune ---

  Future<void> verifierCommune({
    required double latitude,
    required double longitude,
    required List<PointInteret> tousLesPois,
  }) async {
    final commune = await _obtenirCommune(latitude, longitude);
    if (commune == null) return;

    final polygone = await _obtenirPolygoneNominatim(commune);

    final int totalPois;
    final int poisLus;

    if (polygone != null) {
      _polygoneActuel = polygone;
      final poisDansCommune = tousLesPois
          .where((p) =>
              p.status == PoiStatus.validated &&
              _estDansPolygone(p.latitude, p.longitude, polygone))
          .toList();
      totalPois = poisDansCommune.length;
      poisLus = poisDansCommune.where((p) => _poisLus.contains(p.id)).length;
    } else {
      totalPois = 0;
      poisLus = 0;
    }

    if (commune != _communeActuelle) {
      _communeActuelle = commune;
      await _annoncer(commune, totalPois, poisLus);
    }
  }

  // --- Géocodage inverse (Nominatim) ---

  Future<String?> _obtenirCommune(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lon&zoom=10',
      );
      final response = await http.get(uri, headers: {
        'Accept-Language': 'fr',
        'User-Agent': 'FaYoWApp/1.0',
      });
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;
      return address?['city'] as String? ??
          address?['town'] as String? ??
          address?['village'] as String?;
    } catch (_) {
      return null;
    }
  }

  // --- Polygone Nominatim ---

  Future<List<List<double>>?> _obtenirPolygoneNominatim(String commune) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(commune)}&format=json&polygon_geojson=1&limit=1',
      );
      final response = await http.get(uri, headers: {
        'Accept-Language': 'fr',
        'User-Agent': 'FaYoWApp/1.0',
      });
      if (response.statusCode != 200) return null;

      final results = jsonDecode(response.body) as List<dynamic>;
      if (results.isEmpty) return null;

      final geojson = results.first['geojson'] as Map<String, dynamic>?;
      if (geojson == null) return null;

      return _extraireCoordonnees(geojson);
    } catch (_) {
      return null;
    }
  }

  List<List<double>>? _extraireCoordonnees(Map<String, dynamic> geojson) {
    final type = geojson['type'] as String?;
    final coords = geojson['coordinates'];

    if (type == 'Polygon') {
      return (coords[0] as List).map((c) => [
            (c[0] as num).toDouble(),
            (c[1] as num).toDouble(),
          ]).toList();
    } else if (type == 'MultiPolygon') {
      // Prend le plus grand polygone
      final polygons = coords as List;
      polygons.sort((a, b) => (b[0] as List).length - (a[0] as List).length);
      return (polygons.first[0] as List).map((c) => [
            (c[0] as num).toDouble(),
            (c[1] as num).toDouble(),
          ]).toList();
    }
    return null;
  }

  // --- Ray-casting ---

  bool _estDansPolygone(
      double lat, double lon, List<List<double>> polygone) {
    int intersections = 0;
    final int n = polygone.length;

    for (int i = 0, j = n - 1; i < n; j = i++) {
      final double xi = polygone[i][0], yi = polygone[i][1]; // lon, lat
      final double xj = polygone[j][0], yj = polygone[j][1];

      final bool intersecte =
          ((yi > lat) != (yj > lat)) &&
          (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi);

      if (intersecte) intersections++;
    }
    return intersections % 2 == 1;
  }

  // --- Annonces TTS ---

  Future<void> _annoncer(String commune, int total, int lus) async {
    if (!_ttsReady) return;

    final String message;

    if (total == 0) {
      message = 'Vous entrez dans $commune. Aucun point d\'intérêt recensé.';
    } else if (lus == 0) {
      message =
          'Vous entrez dans $commune. $total point${total > 1 ? 's' : ''} '
          'd\'intérêt à découvrir.';
    } else if (lus < total) {
      final restants = total - lus;
      message =
          'Vous entrez dans $commune. $restants point${restants > 1 ? 's' : ''} '
          'd\'intérêt non encore visité${restants > 1 ? 's' : ''}.';
    } else {
      message =
          'Vous entrez dans $commune. Vous avez visité tous les points d\'intérêt !';
    }

    await _tts.speak(message);
  }
}