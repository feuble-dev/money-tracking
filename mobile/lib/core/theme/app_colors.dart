import 'package:flutter/material.dart';

/// Couleurs de l'application MoneyTracking
class AppColors {
  AppColors._();

  // Couleur primaire : Bleu profond moderne
  static const Color primaryColor = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF0D47A1);

  // Couleur secondaire (accents uniquement)
  static const Color accentColor = Color(0xFFFF6B35);

  // Dépôt = bleu (argent sort de l'agent)
  static const Color depositColor = Color(0xFF1565C0);
  // Retrait = vert (argent entre chez l'agent)
  static const Color withdrawColor = Color(0xFF2E7D32);

  // Light theme surfaces
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFEEF2F7);

  // Dark theme surfaces
  static const Color darkBackground = Color(0xFF0F1923);
  static const Color darkSurface = Color(0xFF1A2535);
  static const Color darkCard = Color(0xFF243044);
}
