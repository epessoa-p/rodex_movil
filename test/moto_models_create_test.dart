import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/inventory/catalogs_repository.dart';
import 'package:rodex_movil/features/inventory/moto_models_field.dart';

class _FakeCatalogs extends CatalogsRepository {
  _FakeCatalogs() : super(ApiClient());

  final created = <String>[];
  final models = <CatalogItem>[
    const CatalogItem(id: 1, name: 'CG 150', motoBrandId: 10, brand: 'HONDA'),
  ];
  final brands = <CatalogItem>[
    const CatalogItem(id: 10, name: 'HONDA'),
    const CatalogItem(id: 11, name: 'SUZUKI'),
  ];

  @override
  Future<List<CatalogItem>> list(CatalogType type, {String q = ''}) async {
    if (type == CatalogType.motoBrands) return brands;
    final t = q.toUpperCase();
    return models
        .where((m) => t.isEmpty || '${m.brand} ${m.name}'.contains(t))
        .toList();
  }

  @override
  Future<CatalogItem> create(
    CatalogType type, {
    required String name,
    Map<String, dynamic> extra = const {},
  }) async {
    if (type == CatalogType.motoBrands) {
      created.add('marca:$name');
      final b = CatalogItem(id: 20, name: name);
      brands.add(b);
      return b;
    }
    final brandId = extra['moto_brand_id'] as int;
    final brand = brands.firstWhere((b) => b.id == brandId).name;
    created.add('modelo:$brand $name');
    final m = CatalogItem(
      id: 100 + models.length,
      name: name,
      motoBrandId: brandId,
      brand: brand,
      engineCc: extra['engine_cc'] as String?,
    );
    models.add(m);
    return m;
  }
}

Widget _app(_FakeCatalogs repo, List<List<CatalogItem>> out) => ProviderScope(
  overrides: [catalogsRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (context, setState) => MotoModelsField(
            value: out.isEmpty ? const [] : out.last,
            onChanged: (v) => setState(() => out.add(v)),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pump(const Duration(milliseconds: 400)); // búsqueda con espera
  await tester.pumpAndSettle();
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('"HONDA RX 200": adivina la marca, crea el modelo y lo marca', (
    tester,
  ) async {
    await _phone(tester);
    final repo = _FakeCatalogs();
    final out = <List<CatalogItem>>[];
    await tester.pumpWidget(_app(repo, out));
    await tester.tap(find.byType(MotoModelsField));
    await tester.pumpAndSettle();

    await _type(tester, 'HONDA RX 200');
    expect(find.text('Crear «HONDA RX 200»'), findsOneWidget);
    await tester.tap(find.text('Crear «HONDA RX 200»'));
    await tester.pumpAndSettle();

    // Ventana: marca HONDA elegida y el resto como nombre del modelo.
    expect(find.text('Nuevo modelo'), findsOneWidget);
    expect(find.text('HONDA'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'RX 200'), findsOneWidget);

    await tester.tap(find.text('Crear y agregar'));
    await tester.pumpAndSettle();

    expect(repo.created, ['modelo:HONDA RX 200']);
    // Queda marcado en la hoja y la búsqueda se limpia.
    expect(find.text('Listo · 1 modelo'), findsOneWidget);
    await tester.tap(find.text('Listo · 1 modelo'));
    await tester.pumpAndSettle();
    expect(out.last.map((m) => m.name), ['RX 200']);
    expect(find.text('HONDA RX 200'), findsOneWidget); // chip
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Marca que no existe: se escribe y se crean marca y modelo', (
    tester,
  ) async {
    await _phone(tester);
    final repo = _FakeCatalogs();
    await tester.pumpWidget(_app(repo, []));
    await tester.tap(find.byType(MotoModelsField));
    await tester.pumpAndSettle();

    await _type(tester, 'RX1');
    await tester.tap(find.text('Crear «RX1»'));
    await tester.pumpAndSettle();

    // Sin marca adivinada: elegir "Otra marca…" y escribirla.
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('➕ Otra marca…').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Marca nueva *'),
      'zongshen',
    );
    await tester.tap(find.text('Crear y agregar'));
    await tester.pumpAndSettle();

    expect(repo.created, ['marca:ZONGSHEN', 'modelo:ZONGSHEN RX1']);
    expect(find.text('Listo · 1 modelo'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Sin marca elegida no crea nada y lo avisa', (tester) async {
    await _phone(tester);
    final repo = _FakeCatalogs();
    await tester.pumpWidget(_app(repo, []));
    await tester.tap(find.byType(MotoModelsField));
    await tester.pumpAndSettle();

    await _type(tester, 'RX1');
    await tester.tap(find.text('Crear «RX1»'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear y agregar'));
    await tester.pumpAndSettle();

    expect(repo.created, isEmpty);
    expect(find.text('Elige la marca del vehículo.'), findsOneWidget);
    expect(find.text('Nuevo modelo'), findsOneWidget); // sigue abierta
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Lo que ya existe no ofrece "Crear"', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(_FakeCatalogs(), []));
    await tester.tap(find.byType(MotoModelsField));
    await tester.pumpAndSettle();

    await _type(tester, 'HONDA CG 150');
    expect(find.textContaining('Crear «'), findsNothing);
    await _type(tester, 'CG 150');
    expect(find.textContaining('Crear «'), findsNothing);
    expect(find.text('CG 150'), findsWidgets);
  });
}
