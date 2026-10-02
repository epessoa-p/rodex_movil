import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_toast.dart';
import '../../core/format.dart';
import '../../core/sheet_focus.dart';
import '../../core/upper_case.dart';
import 'cart.dart';

/// Color de la venta rápida (mismo ámbar del botón "Venta rápida" de la web).
const kQuickSaleColor = Color(0xFFF59E0B);

/// Abre la hoja "Venta rápida": para vender algo que está en físico pero no en
/// el inventario. [initialName] llega desde el buscador cuando no encontró el
/// producto, así no hay que volver a escribirlo.
Future<void> showQuickItemSheet(
  BuildContext context, {
  String initialName = '',
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => QuickItemSheet(initialName: initialName),
);

class QuickItemSheet extends ConsumerStatefulWidget {
  final String initialName;
  const QuickItemSheet({super.key, this.initialName = ''});

  @override
  ConsumerState<QuickItemSheet> createState() => _QuickItemSheetState();
}

class _QuickItemSheetState extends ConsumerState<QuickItemSheet> {
  late final _name = TextEditingController(
    text: widget.initialName.trim().toUpperCase(),
  );
  final _price = TextEditingController();
  // Foco diferido (nunca autofocus en hojas): en el nombre, o en el precio si
  // el nombre ya vino escrito desde el buscador.
  late final _nameFocus = SheetFocus(this);
  final _priceFocus = FocusNode();
  int _qty = 1;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialName.trim().isNotEmpty) {
      // Con nombre: el teclado se abre directo en el precio.
      Future.delayed(const Duration(milliseconds: 360), () {
        if (mounted) _priceFocus.requestFocus();
      });
    }
    _price.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _nameFocus.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  double? get _priceValue =>
      double.tryParse(_price.text.trim().replaceAll(',', '.'));

  String? get _nameError => _tried && _name.text.trim().isEmpty
      ? 'Escribe qué estás vendiendo'
      : null;

  String? get _priceError {
    if (!_tried) return null;
    final p = _priceValue;
    return (p == null || p <= 0) ? 'Indica el precio' : null;
  }

  void _add() {
    setState(() => _tried = true);
    final name = _name.text.trim().toUpperCase();
    final price = _priceValue;
    if (name.isEmpty || price == null || price <= 0) return;

    ref
        .read(cartProvider.notifier)
        .addDirect(name: name, price: price, quantity: _qty.toDouble());
    Navigator.pop(context);
    AppToast.success(context, '«$name» agregado al carrito.');
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final total = (_priceValue ?? 0) * _qty;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kQuickSaleColor.withValues(alpha: .15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt, color: kQuickSaleColor),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Venta rápida',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Algo que tienes en físico pero no en el inventario',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              focusNode: _nameFocus.node,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: upperCaseFormatters,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_tried) setState(() {});
              },
              onSubmitted: (_) => _priceFocus.requestFocus(),
              decoration: InputDecoration(
                labelText: 'Producto *',
                hintText: 'Ej. EMPAQUE DE MOTOR GENÉRICO',
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _price,
                    focusNode: _priceFocus,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(
                      labelText: 'Precio *',
                      prefixText: '$currencySymbol ',
                      errorText: _priceError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _QtyStepper(
                  value: _qty,
                  onChanged: (v) => setState(() => _qty = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Total de la línea en vivo.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _qty > 1
                          ? '$_qty × ${money(_priceValue ?? 0)}'
                          : 'Total de la línea',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                  Text(
                    money(total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.amber.shade800,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Si el nombre coincide con un producto registrado, se '
                    'descuenta su stock al vender.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Agregar al carrito'),
              onPressed: _add,
            ),
          ],
        ),
      ),
    );
  }
}

/// − cantidad + (mínimo 1).
class _QtyStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _QtyStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black38),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Menos',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove),
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Más',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add),
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}
