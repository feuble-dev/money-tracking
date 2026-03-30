import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Avatar réutilisable pour afficher le logo d'un opérateur
/// Affiche le logo si disponible, sinon l'initiale du nom
class OperatorAvatar extends StatelessWidget {
  final String name;
  final String? logoPath;
  final double radius;

  const OperatorAvatar({
    super.key,
    required this.name,
    this.logoPath,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoPath != null && File(logoPath!).existsSync();

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryColor.withAlpha(20),
      backgroundImage: hasLogo ? FileImage(File(logoPath!)) : null,
      child: hasLogo
          ? null
          : Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
                fontSize: radius * 0.85,
              ),
            ),
    );
  }
}
