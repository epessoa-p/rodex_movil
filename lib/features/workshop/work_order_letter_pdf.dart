import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/pdf_letter.dart';

const _payLabels = {
  'pendiente': 'Pendiente',
  'parcial': 'Parcial',
  'pagada': 'Pagada',
};

/// Orden de trabajo en **tamaño carta**: cabecera con logo, cliente y
/// vehículo, recepción (falla, diagnóstico, km, combustible), tablas de
/// servicios y repuestos, totales y firmas.
Future<Uint8List> buildWorkOrderLetterPdf(
  WorkOrder o, {
  Company? company,
  Uint8List? logo,
}) async {
  final L = LetterDoc(company: company, logo: logo);
  String? date;
  if (o.receptionDate != null) {
    final d = DateTime.tryParse(o.receptionDate!);
    if (d != null) date = DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
  }
  final payLabel = _payLabels[o.paymentStatus] ?? o.paymentStatus;

  final doc = L.document(
    (ctx) => [
      L.header(
        title: 'Orden de trabajo',
        code: o.code,
        date: date != null ? 'Recepción: $date' : null,
        subtitle: 'Estado: ${o.statusLabel}',
      ),
      L.cards([
        L.card('Cliente', [
          L.field('Nombre', o.client),
          L.field('Teléfono', o.clientPhone),
        ]),
        L.card('Vehículo', [
          L.field('Moto', o.vehicle),
          L.field('Kilometraje', o.mileage != null ? '${o.mileage} km' : null),
          L.field('Combustible', o.fuelLevel),
        ]),
        L.card('Taller', [
          L.field('Mecánico', o.mechanic),
          L.field('Estado de pago', payLabel),
        ]),
      ]),
      if ((o.reportedIssue ?? '').trim().isNotEmpty ||
          (o.diagnosis ?? '').trim().isNotEmpty ||
          (o.receivedItems ?? '').trim().isNotEmpty) ...[
        L.sectionTitle('Recepción y diagnóstico'),
        L.cards([
          L.card('Falla reportada', [L.field('Descripción', o.reportedIssue)]),
          L.card('Diagnóstico', [L.field('Detalle', o.diagnosis)]),
        ]),
        if ((o.receivedItems ?? '').trim().isNotEmpty)
          L.note('Recibido con: ${o.receivedItems}'),
      ],
      if (o.services.isNotEmpty) ...[
        L.sectionTitle('Servicios'),
        L.table(
          headers: const ['#', 'Servicio', 'Cant.', 'Precio', 'Subtotal'],
          widths: const [0.5, 6, 1, 1.6, 1.6],
          numeric: const {2, 3, 4},
          rows: [
            for (var i = 0; i < o.services.length; i++)
              [
                '${i + 1}',
                o.services[i].description +
                    (o.services[i].mechanic != null
                        ? '  (${o.services[i].mechanic})'
                        : ''),
                '${o.services[i].quantity}',
                money(o.services[i].price),
                money(o.services[i].subtotal),
              ],
          ],
        ),
      ],
      if (o.parts.isNotEmpty) ...[
        L.sectionTitle('Repuestos'),
        L.table(
          headers: const ['#', 'Repuesto', 'Cant.', 'P. unit.', 'Subtotal'],
          widths: const [0.5, 6, 1, 1.6, 1.6],
          numeric: const {2, 3, 4},
          rows: [
            for (var i = 0; i < o.parts.length; i++)
              [
                '${i + 1}',
                o.parts[i].name,
                '${o.parts[i].quantity}',
                money(o.parts[i].unitPrice),
                money(o.parts[i].subtotal),
              ],
          ],
        ),
      ],
      L.totals([
        if (o.subtotalServices > 0)
          TotalLine('Servicios', money(o.subtotalServices)),
        if (o.subtotalParts > 0) TotalLine('Repuestos', money(o.subtotalParts)),
        if (o.discount > 0) TotalLine('Descuento', '-${money(o.discount)}'),
        TotalLine('TOTAL', money(o.total), emphasis: true),
        TotalLine('Pagado', money(o.paidAmount), success: true),
        if (o.balance > 0)
          TotalLine('Saldo pendiente', money(o.balance), danger: true),
      ]),
      if ((o.notes ?? '').trim().isNotEmpty) L.note('Notas: ${o.notes}'),
      L.signature('Conformidad del cliente'),
      L.thanks('¡Gracias por su preferencia!'),
    ],
  );
  return doc.save();
}
