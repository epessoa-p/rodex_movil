import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/inventory/public_catalog_screen.dart';

void main() {
  final links = [
    CatalogLink(
      id: 1,
      name: 'Sucursal Central Avenida Banzer',
      address: 'Av. Banzer 4to anillo, Santa Cruz',
      url:
          'https://rodex.example.com/catalogo/sucursal/AbCdEfGhIjKlMnOpQrStUvWxYz012345',
      pdfUrl: 'https://rodex.example.com/catalogo/sucursal/AbCd/pdf',
    ),
    CatalogLink(
      id: 2,
      name: 'Norte',
      url: 'https://rodex.example.com/catalogo/sucursal/zzz',
      pdfUrl: 'https://rodex.example.com/catalogo/sucursal/zzz/pdf',
    ),
  ];

  testWidgets('lista las sucursales con QR, enlace y acciones a 360 dp', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      ProviderScope(
        overrides: [catalogLinksProvider.overrideWith((ref) async => links)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PublicCatalogScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Sucursal Central Avenida Banzer'), findsOneWidget);
    expect(find.text('Av. Banzer 4to anillo, Santa Cruz'), findsOneWidget);
    expect(find.text(links[0].url), findsOneWidget);
    expect(find.byType(QrView), findsWidgets);
    expect(find.text('Compartir enlace'), findsWidgets);
    expect(find.text('PDF'), findsWidgets);
    expect(find.text('Descargar QR'), findsWidgets);
    expect(t.takeException(), isNull);

    // La segunda sucursal (sin dirección) también se ve al bajar.
    await t.drag(find.byType(ListView), const Offset(0, -900));
    await t.pumpAndSettle();
    expect(find.text('Catálogo de esta sucursal'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('slug para el nombre del archivo', () {
    expect(links[0].slug, 'sucursal-central-avenida-banzer');
  });

  testWidgets('el QR se exporta como PNG', (t) async {
    final png = await t.runAsync(
      () => buildCatalogQrPng(links[0].url, caption: links[0].name),
    );
    // Firma PNG.
    expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(png.length, greaterThan(1000));
  });
}
