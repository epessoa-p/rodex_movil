import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/inventory/catalog_builder_sheet.dart';

const _options = CatalogFilterOptions(
  categories: [
    CatalogOption(id: 1, name: 'CASCOS'),
    CatalogOption(id: 2, name: 'ACEITES'),
    CatalogOption(id: 3, name: 'TRANSMISION'),
  ],
  brands: [CatalogOption(id: 5, name: 'MOTUL')],
  models: [
    CatalogOption(id: 7, name: 'CG 150', brand: 'HONDA'),
    CatalogOption(id: 9, name: 'CB 190', brand: 'HONDA'),
  ],
);

void main() {
  test('la selección arma la URL del catálogo', () {
    const url = 'https://rodex.bo/catalogo/sucursal/tok1/pdf';
    expect(const CatalogSelection().applyTo(url), url);
    expect(
      const CatalogSelection(
        categories: {2, 1},
        models: {7},
        onlyInStock: true,
      ).applyTo(url),
      '$url?cat=1,2&mod=7&stock=1',
    );
    expect(
      const CatalogSelection(brands: {5}).applyTo('$url?viejo=1'),
      '$url?mar=5',
    );
  });

  testWidgets(
    'elegir filtros: cuenta en vivo, avisa si son muchos y baja el PDF '
    'de la selección',
    (t) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      final counted = <Map<String, String>>[];
      CatalogSelection? pdfSel, shareSel;
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CatalogBuilderSheet(
              branchName: 'Central',
              options: _options,
              warnAt: 500,
              count: (s) async {
                counted.add(s.query);
                // Todo = 1176; con filtros, menos.
                return s.isEmpty ? 1176 : (s.onlyInStock ? 0 : 38);
              },
              onPdf: (s) async => pdfSel = s,
              onShare: (s) async => shareSel = s,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      // Sin filtros: todo el catálogo y aviso.
      expect(find.textContaining('1176 productos'), findsOneWidget);
      expect(find.textContaining('el PDF puede tardar'), findsOneWidget);
      expect(t.takeException(), isNull);

      // Elegir Cascos + Aceites y el modelo CG.
      await t.tap(find.text('CASCOS'));
      await t.tap(find.text('ACEITES'));
      await t.pump();
      expect(find.text('Categorías (2)'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('CG 150 · HONDA'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.ensureVisible(find.text('CG 150 · HONDA'));
      await t.pumpAndSettle();
      await t.tap(find.text('CG 150 · HONDA'));
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(find.text('38 productos'), findsOneWidget);
      expect(find.textContaining('el PDF puede tardar'), findsNothing);
      expect(counted.last, {'cat': '1,2', 'mod': '7'});

      await t.ensureVisible(find.byKey(const Key('builder_pdf')));
      await t.tap(find.byKey(const Key('builder_pdf')));
      await t.pumpAndSettle();
      expect(pdfSel!.query, {'cat': '1,2', 'mod': '7'});

      await t.tap(find.byKey(const Key('builder_share')));
      await t.pumpAndSettle();
      expect(shareSel!.categories, {1, 2});

      // "Solo disponibles" sin resultados: no deja bajar un PDF vacío.
      // Está arriba de la lista: volver a subir.
      await t.scrollUntilVisible(
        find.byKey(const Key('only_stock')),
        -100,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.tap(find.byKey(const Key('only_stock')));
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(find.text('0 productos'), findsOneWidget);
      final pdfBtn = t.widget<ButtonStyleButton>(
        find.byKey(const Key('builder_pdf')),
      );
      expect(pdfBtn.onPressed, isNull);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('muchas opciones: buscador que filtra los chips', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final many = CatalogFilterOptions(
      categories: [
        for (var i = 1; i <= 20; i++)
          CatalogOption(id: i, name: 'CATEGORIA $i'),
      ],
    );
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CatalogBuilderSheet(
            branchName: 'Central',
            options: many,
            count: (_) async => 10,
            onPdf: (_) async {},
            onShare: (_) async {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'categoria 1');
    await t.pumpAndSettle();
    // "CATEGORIA 1" y "CATEGORIA 10"…"19".
    expect(find.byType(FilterChip), findsNWidgets(11));
    expect(t.takeException(), isNull);
  });
}
