import 'package:flutter/material.dart';

import '../../core/app_toast.dart';
import '../../core/format.dart';
import '../../core/sheet_focus.dart';
import '../../core/upper_case.dart';
import '../agenda/agenda_repository.dart';

/// Servicio elegido en [AddServiceSheet] (nombre, precio, cantidad).
class ServicePick {
  final String name;
  final double price;
  final int quantity;
  const ServicePick(this.name, this.price, this.quantity);
}

/// Hoja grande (como la de Nueva cita) para agregar un servicio a la OT:
/// buscador sobre el catálogo (precarga el precio) o uno nuevo escrito a
/// mano; abajo precio y cantidad.
class AddServiceSheet extends StatefulWidget {
  final List<ServiceOption> catalog;
  const AddServiceSheet({super.key, required this.catalog});

  @override
  State<AddServiceSheet> createState() => AddServiceSheetState();
}

class AddServiceSheetState extends State<AddServiceSheet> {
  final _query = TextEditingController();
  final _price = TextEditingController();
  final _qty = TextEditingController(text: '1');
  // Foco diferido: nunca `autofocus` dentro de una hoja (ANR en MIUI).
  late final SheetFocus _focus = SheetFocus(this);
  ServiceOption? _selected;

  @override
  void dispose() {
    _query.dispose();
    _price.dispose();
    _qty.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Nombre a registrar: el elegido del catálogo o lo escrito.
  String get _name => _selected?.name ?? _query.text.trim();

  void _pick(ServiceOption s) => setState(() {
    _selected = s;
    _query.text = s.name;
    if (s.price > 0) _price.text = s.price.toStringAsFixed(2);
  });

  void _submit() {
    final name = _name;
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.'));
    final qty = int.tryParse(_qty.text.trim()) ?? 1;
    if (name.isEmpty) {
      AppToast.error(
        context,
        'Elige un servicio del catálogo o escribe uno.',
        title: 'Falta el servicio',
      );
      return;
    }
    if (price == null || price < 0) {
      AppToast.error(
        context,
        'Ingresa un precio válido (puede ser 0).',
        title: 'Precio inválido',
      );
      return;
    }
    Navigator.pop(context, ServicePick(name, price, qty < 1 ? 1 : qty));
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final items = q.isEmpty
        ? widget.catalog
        : widget.catalog
              .where((s) => s.name.toLowerCase().contains(q))
              .toList();
    // Lo escrito no coincide con ninguno del catálogo → se creará nuevo.
    final isNew =
        _selected == null &&
        q.isNotEmpty &&
        !widget.catalog.any((s) => s.name.toLowerCase() == q);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .75,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.handyman_outlined,
                      size: 18,
                      color: Colors.black54,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Agregar servicio',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _query,
                  focusNode: _focus.node,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: upperCaseFormatters,
                  onChanged: (_) => setState(() => _selected = null),
                  decoration: InputDecoration(
                    hintText: 'Buscar en el catálogo o escribir uno nuevo…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: q.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() {
                              _query.clear();
                              _selected = null;
                            }),
                          ),
                  ),
                ),
              ),
              if (isNew)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.fiber_new_outlined,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '«${_query.text.trim()}» se creará como servicio nuevo.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          'Sin coincidencias en el catálogo.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final s = items[i];
                          final sel = _selected?.id == s.id;
                          return ListTile(
                            dense: true,
                            selected: sel,
                            leading: Icon(
                              sel
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: sel ? Colors.green : Colors.black38,
                            ),
                            title: Text(s.name),
                            trailing: s.price > 0 ? Text(money(s.price)) : null,
                            onTap: () => _pick(s),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Precio *',
                          prefixText: '$currencySymbol ',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _qty,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                  icon: const Icon(Icons.check),
                  label: Text(
                    _name.isEmpty ? 'Agregar' : 'Agregar «$_name»',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
