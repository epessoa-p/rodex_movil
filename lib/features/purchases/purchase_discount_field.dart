import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';

/// Descuento que da el proveedor sobre el total de una compra / OC.
/// Se guarda como lo escribió el usuario: en % (se mantiene si cambian los
/// productos) o en monto. Al servidor viaja siempre el monto ([amountFor]).
class SupplierDiscount {
  final bool isPercent;
  final double value;

  const SupplierDiscount.none() : isPercent = false, value = 0;
  const SupplierDiscount.percent(this.value) : isPercent = true;
  const SupplierDiscount.amount(this.value) : isPercent = false;

  /// Monto del descuento para [subtotal] (entre 0 y el subtotal).
  double amountFor(double subtotal) {
    final raw = isPercent ? subtotal * value / 100 : value;
    final clamped = raw.clamp(0, subtotal < 0 ? 0 : subtotal).toDouble();
    return (clamped * 100).roundToDouble() / 100;
  }
}

/// Bloque "Descuento del proveedor" + "Total a pagar" editable. El % , el
/// monto y el total se mantienen sincronizados: escribir el total que cobra
/// el proveedor calcula el descuento solo.
///
/// El padre guarda el [SupplierDiscount] y recibe los cambios por [onChanged]
/// (solo por acción del usuario, nunca al construir).
class PurchaseDiscountField extends StatefulWidget {
  final double subtotal;
  final SupplierDiscount value;
  final ValueChanged<SupplierDiscount> onChanged;

  const PurchaseDiscountField({
    super.key,
    required this.subtotal,
    required this.value,
    required this.onChanged,
  });

  @override
  State<PurchaseDiscountField> createState() => _PurchaseDiscountFieldState();
}

class _PurchaseDiscountFieldState extends State<PurchaseDiscountField> {
  final _pct = TextEditingController();
  final _amt = TextEditingController();
  final _total = TextEditingController();
  final _pctFocus = FocusNode();
  final _amtFocus = FocusNode();
  final _totalFocus = FocusNode();
  String? _totalWarning;

  static final _decimal = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
  ];

  double get _discount => widget.value.amountFor(widget.subtotal);

  @override
  void initState() {
    super.initState();
    _sync();
    // Al salir del total se muestra el valor realmente aplicado.
    _totalFocus.addListener(() {
      if (!_totalFocus.hasFocus) {
        _total.text = _fmt(widget.subtotal - _discount);
        if (_totalWarning != null) setState(() => _totalWarning = null);
      }
    });
  }

  @override
  void didUpdateWidget(covariant PurchaseDiscountField old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    for (final c in [_pct, _amt, _total]) {
      c.dispose();
    }
    for (final f in [_pctFocus, _amtFocus, _totalFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  static String _fmt(double v) => v.toStringAsFixed(2);

  static String _fmtPct(double v) {
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static double? _parse(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  /// Rellena los campos que el usuario NO está editando.
  void _sync() {
    final d = _discount;
    final sub = widget.subtotal;
    if (!_pctFocus.hasFocus) {
      _pct.text = d > 0 && sub > 0 ? _fmtPct(d / sub * 100) : '';
    }
    if (!_amtFocus.hasFocus) _amt.text = d > 0 ? _fmt(d) : '';
    if (!_totalFocus.hasFocus) _total.text = _fmt(sub - d);
  }

  void _onPct(String s) =>
      widget.onChanged(SupplierDiscount.percent(_parse(s) ?? 0));

  void _onAmt(String s) =>
      widget.onChanged(SupplierDiscount.amount(_parse(s) ?? 0));

  void _onTotal(String s) {
    final t = _parse(s);
    var d = t == null ? 0.0 : widget.subtotal - t;
    String? warn;
    if (d < 0) {
      d = 0;
      warn =
          'El total no puede ser mayor al subtotal (${money(widget.subtotal)}).';
    }
    if (warn != _totalWarning) setState(() => _totalWarning = warn);
    widget.onChanged(SupplierDiscount.amount((d * 100).roundToDouble() / 100));
  }

  String? get _warning {
    if (_totalWarning != null) return _totalWarning;
    final v = widget.value;
    if (v.isPercent && v.value > 100) {
      return 'El porcentaje no puede pasar de 100%.';
    }
    if (!v.isPercent && v.value > widget.subtotal) {
      return 'El descuento no puede pasar del subtotal.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final d = _discount;
    final active = d > 0;
    final green = Colors.green.shade700;
    final warning = _warning;

    InputDecoration deco({String? prefix, String? suffix, String? hint}) =>
        InputDecoration(
          isDense: true,
          hintText: hint,
          prefixText: prefix,
          suffixText: suffix,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal', style: TextStyle(color: Colors.black54)),
            Text(money(widget.subtotal)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          decoration: BoxDecoration(
            color: green.withValues(alpha: active ? .10 : .05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: green.withValues(alpha: active ? .5 : .25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.sell_outlined, size: 18, color: green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Descuento del proveedor',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: green,
                      ),
                    ),
                  ),
                  if (active)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        setState(() => _totalWarning = null);
                        widget.onChanged(const SupplierDiscount.none());
                      },
                      child: const Text('Quitar'),
                    )
                  else
                    const SizedBox(height: 32),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: TextField(
                      key: const Key('discount_pct'),
                      controller: _pct,
                      focusNode: _pctFocus,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: _decimal,
                      textAlign: TextAlign.end,
                      decoration: deco(suffix: '%', hint: '0'),
                      onChanged: _onPct,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const Key('discount_amount'),
                      controller: _amt,
                      focusNode: _amtFocus,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: _decimal,
                      textAlign: TextAlign.end,
                      decoration: deco(
                        prefix: '$currencySymbol ',
                        hint: '0.00',
                      ),
                      onChanged: _onAmt,
                    ),
                  ),
                ],
              ),
              if (warning != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    warning,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Total a pagar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 150,
              child: TextField(
                key: const Key('discount_total'),
                controller: _total,
                focusNode: _totalFocus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: _decimal,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                decoration: deco(prefix: '$currencySymbol '),
                onChanged: _onTotal,
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            '¿El proveedor te cobra otro total? Escríbelo y el descuento se calcula solo.',
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ),
      ],
    );
  }
}
