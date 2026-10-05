import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class LoginStyles {
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color deepGreen = Color(0xFF163D2E);
  static const Color forestGreen = Color(0xFF2E5E47);
  static const Color accentGold = Color(0xFFE0A14D);
  static const Color warmBeige = Color(0xFFEAE1D2);
  static const Color softCream = Color(0xFFF5F0E8);

  static const LinearGradient screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [deepGreen, forestGreen, warmBeige],
  );

  static Widget buildLogo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 118,
          height: 118,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [primaryGreen, accentGold],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1F4D3D).withAlpha(90),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.terrain_rounded,
            size: 58,
            color: Colors.white,
          ),
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
            color: isDark ? Colors.white : const Color(0xFF2E5E47),
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
