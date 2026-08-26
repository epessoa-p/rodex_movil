import 'package:intl/intl.dart';

String _currencySymbol = 'Bs';
NumberFormat _money =
    NumberFormat.currency(symbol: '$_currencySymbol ', decimalDigits: 2);

/// Ajusta el símbolo de moneda a la de la empresa activa (se llama al cargar /me).
void setCurrencySymbol(String? symbol) {
  final s = (symbol ?? '').trim();
  if (s.isEmpty || s == _currencySymbol) return;
  _currencySymbol = s;
  _money = NumberFormat.currency(symbol: '$s ', decimalDigits: 2);
}

String money(num value) => _money.format(value);

/// Símbolo de moneda activo (para prefijos de inputs, etc.).
String get currencySymbol => _currencySymbol;

/// Formatea cantidades: sin decimales si es entero (2), con 2 si no (2.5).
String qty(num value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();
