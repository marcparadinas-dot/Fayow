import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {

  /// À appeler une fois après connexion, avant d'ouvrir MapScreen.
  static Future<void> demanderPermissions(BuildContext context) async {
    // 1. Permission "en cours d'utilisation" d'abord (obligatoire avant background)
    final locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      await Permission.location.request();
    }

    // 2. Permission background (Android uniquement)
    if (Platform.isAndroid) {
      final backgroundStatus = await Permission.locationAlways.status;
      if (!backgroundStatus.isGranted && context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Autoriser en permanence"),
            content: const Text(
              "Dans l'écran suivant, sélectionnez 'Toujours autoriser' "
              "pour que FaYoW puisse vous alerter même quand l'écran est éteint."
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Permission.locationAlways.request();
                },
                child: const Text("OK"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Annuler"),
              ),
            ],
          ),
        );
      }
    }
  }
}