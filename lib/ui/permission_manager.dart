// lib/ui/permission_manager.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class PermissionManager {
  // Callbacks
  void Function()? onAllPermissionsGranted;
  void Function()? onBackgroundPermissionDenied;

  // --- Vérifications ---

  Future<bool> hasFineLocationPermission() async {
    if (_isWebOrDesktop) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> hasBackgroundLocationPermission() async {
    if (_isWebOrDesktop) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  Future<bool> hasAllLocationPermissions() async {
    return await hasBackgroundLocationPermission();
  }

  // --- Demande de permissions (à appeler au démarrage) ---

  Future<void> demanderPermissions(BuildContext context) async {
    if (_isWebOrDesktop) {
      onAllPermissionsGranted?.call();
      return;
    }

    // Vérifie si la localisation est activée sur l'appareil
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        _afficherDialog(
          context,
          titre: 'Localisation désactivée',
          message:
              'Veuillez activer la localisation sur votre appareil pour utiliser cette application.',
          bouton: 'Paramètres',
          onConfirm: () => Geolocator.openLocationSettings(),
        );
      }
      return;
    }

    // Étape 1 — permission "en cours d'utilisation"
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) _afficherDialogParametres(context);
      return;
    }

    if (permission == LocationPermission.denied) {
      if (context.mounted) {
        _afficherDialog(
          context,
          titre: 'Permission refusée',
          message:
              'La localisation est nécessaire pour détecter les points d\'intérêt à proximité.',
          bouton: 'Réessayer',
          onConfirm: () => demanderPermissions(context),
        );
      }
      return;
    }

    // Étape 2 — permission "toujours" (arrière-plan)
    if (permission == LocationPermission.whileInUse) {
      if (context.mounted) {
        await _demanderPermissionArrierePlan(context);
      }
      return;
    }

    // Toutes les permissions accordées
    onAllPermissionsGranted?.call();
  }

  // --- Arrière-plan ---

  Future<void> _demanderPermissionArrierePlan(BuildContext context) async {
    // Explique à l'utilisateur pourquoi on a besoin de la permission arrière-plan
    await _afficherDialog(
      context,
      titre: 'Localisation en arrière-plan',
      message: Platform.isIOS
          ? 'Pour recevoir des alertes même écran éteint, sélectionnez "Toujours" dans les paramètres.'
          : 'Pour recevoir des alertes même écran éteint, autorisez la localisation "Toujours autoriser".',
      bouton: 'Continuer',
      onConfirm: () async {
        final permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.always) {
          onAllPermissionsGranted?.call();
        } else {
          onBackgroundPermissionDenied?.call();
        }
      },
    );
  }

  // --- Dialogs ---

  Future<void> _afficherDialog(
    BuildContext context, {
    required String titre,
    required String message,
    required String bouton,
    required VoidCallback onConfirm,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            child: Text(bouton),
          ),
        ],
      ),
    );
  }

  void _afficherDialogParametres(BuildContext context) {
    _afficherDialog(
      context,
      titre: 'Permission bloquée',
      message:
          'La permission de localisation a été refusée définitivement. '
          'Veuillez l\'activer manuellement dans les paramètres de l\'application.',
      bouton: 'Paramètres',
      onConfirm: () => Geolocator.openAppSettings(),
    );
  }

  // --- Utilitaire ---

  bool get _isWebOrDesktop =>
      !Platform.isAndroid && !Platform.isIOS;
}