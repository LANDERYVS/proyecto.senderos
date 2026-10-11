import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AppStyles {
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color deepGreen = Color(0xFF163D2E);
  static const Color forestGreen = Color(0xFF2E5E47);
  static const Color accentGold = Color(0xFFE0A14D);
  static const Color warmBeige = Color(0xFFEAE1D2);
  static const Color softCream = Color(0xFFF5F0E8);

  static LinearGradient backgroundGradient(Brightness brightness) {
    final colors = brightness == Brightness.dark
        ? const [Color(0xFF101914), Color(0xFF163D2E), Color(0xFF214D36)]
        : const [Color(0xFFE8F5E9), Color(0xFFC8E6C9), Color(0xFFA5D6A7)];
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    );
  }

  static ThemeData theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryGreen,
          brightness: brightness,
        ).copyWith(
          primary: primaryGreen,
          onPrimary: Colors.white,
          secondary: accentGold,
          surface: isDark ? const Color(0xFF202923) : Colors.white,
          onSurface: isDark ? const Color(0xFFF5F0E8) : const Color(0xFF1F2E1D),
        );
    final textTheme = (isDark ? ThemeData.dark() : ThemeData.light()).textTheme
        .apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 1,
        shadowColor: deepGreen.withAlpha(isDark ? 45 : 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: colorScheme.outlineVariant.withAlpha(isDark ? 120 : 90),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF303A33) : softCream,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withAlpha(120),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: deepGreen,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primary.withAlpha(isDark ? 70 : 35),
      ),
    );
  }

  static Widget buildLogo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/icono_senderos.png',
          width: 118,
          height: 118,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 22),
        Text(
          'THOPO',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            letterSpacing: 5,
            color: isDark ? Colors.white : const Color(0xFF1F2E1D),
            shadows: [
              Shadow(
                color: Colors.black.withAlpha(25),
                offset: const Offset(0, 3),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Descubre senderos, vive la aventura',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white70 : const Color(0xFF4D5A4A),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  static Widget buildInputField({
    required BuildContext context,
    required TextEditingController controller,
    required String labelText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1F2E1D)),
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? const Color(0xFF303A33) : softCream,
        labelText: labelText,
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF5E665F),
        ),
        floatingLabelStyle: TextStyle(color: colorScheme.primary),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
    );
  }

  static Widget buildProfileAvatarSelector({
    required BuildContext context,
    required XFile? selectedAvatar,
    required VoidCallback onPick,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final file = selectedAvatar == null ? null : File(selectedAvatar.path);

    return Column(
      children: [
        GestureDetector(
          onTap: onPick,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 54,
                backgroundColor: colorScheme.primary.withAlpha(30),
                backgroundImage: file != null ? FileImage(file) : null,
                child: file == null
                    ? Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 38,
                        color: colorScheme.primary,
                      )
                    : null,
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Foto de perfil',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : forestGreen,
          ),
        ),
      ],
    );
  }

  static ButtonStyle actionButtonStyle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ElevatedButton.styleFrom(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    );
  }
}
