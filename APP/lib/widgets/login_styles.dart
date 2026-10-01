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

  static Widget buildLogo() {
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
            color: const Color(0xFF1F2E1D),
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
        const Text(
          'Descubre senderos, vive la aventura',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF4D5A4A),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  static Widget buildInputField({
    required TextEditingController controller,
    required String labelText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFF1F2E1D)),
      decoration: InputDecoration(
        filled: true,
        fillColor: softCream,
        labelText: labelText,
        labelStyle: const TextStyle(color: Color(0xFF5E665F)),
        floatingLabelStyle: const TextStyle(color: primaryGreen),
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
          borderSide: const BorderSide(color: primaryGreen, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
    );
  }

  static Widget buildProfileAvatarSelector({
    required XFile? selectedAvatar,
    required VoidCallback onPick,
  }) {
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
                backgroundColor: primaryGreen.withAlpha(30),
                backgroundImage: file != null ? FileImage(file) : null,
                child: file == null
                    ? const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 38,
                        color: primaryGreen,
                      )
                    : null,
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: primaryGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
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
        const Text(
          'Foto de perfil',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2E5E47),
          ),
        ),
      ],
    );
  }

  static ButtonStyle actionButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    );
  }
}
