import 'package:flutter/material.dart';

class BotonSosVisual extends StatelessWidget {
  const BotonSosVisual({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red.shade700,
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      child: const SizedBox(
        width: 56,
        height: 40,
        child: Center(
          child: Text(
            'SOS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
