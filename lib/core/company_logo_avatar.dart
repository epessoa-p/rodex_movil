import 'package:flutter/material.dart';

import 'company_logo.dart';

/// Círculo con el logo de la empresa (reducido y cacheado por
/// `loadCompanyLogo`). Mantiene el tamaño del avatar: la imagen se adapta
/// dentro (contain) sin recortarse. Mientras carga o si no hay logo, muestra
/// [fallback] (p. ej. la inicial del usuario).
class CompanyLogoAvatar extends StatelessWidget {
  final String? logoUrl;
  final double radius;
  final Widget fallback;

  const CompanyLogoAvatar({
    super.key,
    required this.logoUrl,
    required this.fallback,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: loadCompanyLogo(logoUrl),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null || bytes.isEmpty) {
          return CircleAvatar(radius: radius, child: fallback);
        }
        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.white,
          child: ClipOval(
            child: Padding(
              padding: EdgeInsets.all(radius * 0.12),
              child: Image.memory(
                bytes,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
        );
      },
    );
  }
}
