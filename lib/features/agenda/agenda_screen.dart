import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../workshop/reception_screen.dart';
import 'agenda_repository.dart';
import 'appointment_form_screen.dart';

const _dow = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _dowFull = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'
];
const _months = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
  'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
];

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

enum _View { day, week, month }

/// Agenda / Citas: vistas de Día, Semana y Mes.
class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  DateTime _selected = DateTime.now();
  _View _view = _View.day;

  DateTime get _dateOnly =>
      DateTime(_selected.year, _selected.month, _selected.day);
  String get _dateStr => _ymd(_dateOnly);

  DateTime get _weekStart => _dateOnly.subtract(Duration(days: _dateOnly.weekday - 1));
  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));
  String get _weekKey => '${_ymd(_weekStart)}|${_ymd(_weekEnd)}';

  DateTime get _monthGridStart {
    final first = DateTime(_dateOnly.year, _dateOnly.month, 1);
    return first.subtract(Duration(days: first.weekday - 1));
  }

  DateTime get _monthGridEnd {
    final last = DateTime(_dateOnly.year, _dateOnly.month + 1, 0);
    return last.add(Duration(days: 7 - last.weekday));
  }

  String get _monthKey => '${_ymd(_monthGridStart)}|${_ymd(_monthGridEnd)}';

  void _go(DateTime d) => setState(() => _selected = d);

  void _refreshAfterAction() {
    ref.invalidate(agendaDayProvider(_dateStr));
    ref.invalidate(agendaRangeProvider(_weekKey));
    ref.invalidate(agendaRangeProvider(_monthKey));
  }

  Future<void> _openForm({Appointment? edit}) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AppointmentFormScreen(date: _dateOnly, edit: edit),
    ));
    if (saved == true) _refreshAfterAction();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).me;
    final canCreate = me?.can('appointments.create') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          IconButton(
            tooltip: 'Hoy',
            icon: const Icon(Icons.today_outlined),
            onPressed: () => _go(DateTime.now()),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SegmentedButton<_View>(
              segments: const [
                ButtonSegment(value: _View.day, label: Text('Día')),
                ButtonSegment(value: _View.week, label: Text('Semana')),
                ButtonSegment(value: _View.month, label: Text('Mes')),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
              showSelectedIcon: false,
            ),
          ),
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Nueva cita'),
            )
          : null,
      body: switch (_view) {
        _View.day => _buildDay(canCreate),
        _View.week => _buildWeek(),
        _View.month => _buildMonth(),
      },
    );
  }

  // ── Vista DÍA ──────────────────────────────────────────────
  Widget _buildDay(bool canCreate) {
    final dayAsync = ref.watch(agendaDayProvider(_dateStr));
    return Column(
      children: [
        _WeekStrip(weekStart: _weekStart, selected: _dateOnly, onPick: _go),
        _RangeHeader(
          label: _cap('${_dowFull[_dateOnly.weekday - 1]} ${_dateOnly.day} de ${_months[_dateOnly.month - 1]}'),
          onPrev: () => _go(_dateOnly.subtract(const Duration(days: 1))),
          onNext: () => _go(_dateOnly.add(const Duration(days: 1))),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(agendaDayProvider(_dateStr)),
            child: dayAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _errList(e),
              data: (day) => _DayBody(
                day: day,
                onTap: _showActions,
                onNew: canCreate ? () => _openForm() : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Vista SEMANA ───────────────────────────────────────────
  Widget _buildWeek() {
    final async = ref.watch(agendaRangeProvider(_weekKey));
    final label =
        '${_weekStart.day} ${_months[_weekStart.month - 1].substring(0, 3)} — ${_weekEnd.day} ${_months[_weekEnd.month - 1].substring(0, 3)}';
    return Column(
      children: [
        _RangeHeader(
          label: _cap(label),
          onPrev: () => _go(_dateOnly.subtract(const Duration(days: 7))),
          onNext: () => _go(_dateOnly.add(const Duration(days: 7))),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(agendaRangeProvider(_weekKey)),
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _errList(e),
              data: (list) {
                final byDay = _groupByDate(list);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                  children: [
                    for (int i = 0; i < 7; i++)
                      _weekDaySection(_weekStart.add(Duration(days: i)), byDay),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _weekDaySection(DateTime d, Map<String, List<Appointment>> byDay) {
    final items = byDay[_ymd(d)] ?? [];
    final isToday = _isSameDay(d, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _selected = d;
                  _view = _View.day;
                }),
                child: Text(
                  '${_dow[d.weekday - 1]} ${d.day}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isToday ? Theme.of(context).colorScheme.primary : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${items.length}',
                      style: const TextStyle(fontSize: 11)),
                ),
              const Expanded(child: Divider(indent: 10)),
            ],
          ),
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 4),
            child: Text('—', style: TextStyle(color: Colors.black38)),
          )
        else
          for (final a in items) _ApptCard(appt: a, onTap: () => _showActions(a)),
      ],
    );
  }

  // ── Vista MES ──────────────────────────────────────────────
  Widget _buildMonth() {
    final async = ref.watch(agendaRangeProvider(_monthKey));
    final label = '${_cap(_months[_dateOnly.month - 1])} ${_dateOnly.year}';
    return Column(
      children: [
        _RangeHeader(
          label: label,
          onPrev: () =>
              _go(DateTime(_dateOnly.year, _dateOnly.month - 1, 1)),
          onNext: () =>
              _go(DateTime(_dateOnly.year, _dateOnly.month + 1, 1)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final d in _dow)
                Expanded(
                  child: Center(
                    child: Text(d,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54)),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(agendaRangeProvider(_monthKey)),
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _errList(e),
              data: (list) {
                final counts = _countByDate(list);
                final start = _monthGridStart;
                final totalDays = _monthGridEnd.difference(start).inDays + 1;
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: .74,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: totalDays,
                    itemBuilder: (_, i) {
                      final d = start.add(Duration(days: i));
                      return _MonthCell(
                        day: d,
                        inMonth: d.month == _dateOnly.month,
                        isToday: _isSameDay(d, DateTime.now()),
                        isSelected: _isSameDay(d, _dateOnly),
                        count: counts[_ymd(d)] ?? 0,
                        onTap: () => setState(() {
                          _selected = d;
                          _view = _View.day;
                        }),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Helpers de datos ───────────────────────────────────────
  Map<String, List<Appointment>> _groupByDate(List<Appointment> list) {
    final map = <String, List<Appointment>>{};
    for (final a in list) {
      (map[a.date] ??= []).add(a);
    }
    return map;
  }

  Map<String, int> _countByDate(List<Appointment> list) {
    final map = <String, int>{};
    for (final a in list) {
      map[a.date] = (map[a.date] ?? 0) + 1;
    }
    return map;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _errList(Object e) => ListView(children: [
        const SizedBox(height: 80),
        Center(child: Text('$e', textAlign: TextAlign.center)),
      ]);

  // ── Acciones sobre una cita ────────────────────────────────
  void _showActions(Appointment a) {
    final me = ref.read(authControllerProvider).me;
    final canEdit = me?.can('appointments.edit') ?? false;
    final canDelete = me?.can('appointments.delete') ?? false;
    final canConvert = me?.can('workshop.create') ?? false;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('${a.time} · ${a.displayName}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([
                if (a.title != null && a.title!.isNotEmpty) a.title,
                if (a.vehicleLabel != null) a.vehicleLabel,
                if (a.mechanicName != null) a.mechanicName,
                a.statusLabel,
              ].whereType<String>().join(' · ')),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFF25D366)),
              title: const Text('Contactar por WhatsApp'),
              subtitle: a.displayPhone != null && a.displayPhone!.isNotEmpty
                  ? Text(a.displayPhone!)
                  : const Text('Sin teléfono registrado'),
              onTap: () {
                Navigator.pop(ctx);
                _whatsapp(a);
              },
            ),
            ListTile(
              leading: const Icon(Icons.call_outlined),
              title: const Text('Llamar'),
              onTap: () {
                Navigator.pop(ctx);
                _call(a);
              },
            ),
            const Divider(height: 1),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar / reprogramar'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openForm(edit: a);
                },
              ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Cambiar estado'),
                onTap: () {
                  Navigator.pop(ctx);
                  _changeStatus(a);
                },
              ),
            if (canConvert && a.workOrderId == null)
              ListTile(
                leading: const Icon(Icons.build_circle_outlined,
                    color: Colors.deepPurple),
                title: const Text('Crear Orden de Trabajo'),
                subtitle: a.clientId == null
                    ? const Text('Requiere un cliente registrado')
                    : (a.vehicleId == null
                        ? const Text('Registrarás el vehículo en la recepción')
                        : null),
                enabled: a.clientId != null,
                onTap: () {
                  Navigator.pop(ctx);
                  _convert(a);
                },
              ),
            if (a.workOrderId != null)
              const ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('OT ya creada desde esta cita'),
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Eliminar',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _delete(a);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeStatus(Appointment a) async {
    final status = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in kAppointmentStatuses.entries)
              ListTile(
                leading:
                    Icon(Icons.circle, size: 14, color: _statusColor(e.key)),
                title: Text(e.value),
                trailing: a.status == e.key ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, e.key),
              ),
          ],
        ),
      ),
    );
    if (status == null || status == a.status) return;
    try {
      await ref.read(agendaRepositoryProvider).changeStatus(a.id, status);
      _refreshAfterAction();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _convert(Appointment a) async {
    // Con vehículo → OT directa. Sin vehículo → recepción precargada con el
    // cliente (ahí se registra el vehículo) y se enlaza la cita al guardar.
    if (a.vehicleId != null) {
      try {
        final res = await ref.read(agendaRepositoryProvider).convert(a.id);
        _refreshAfterAction();
        _snack('Orden de trabajo ${res['code'] ?? ''} creada.');
      } on ApiException catch (e) {
        _snack(e.message);
      }
      return;
    }

    if (a.clientId == null) return;
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ReceptionScreen(
        prefillClient: Client(id: a.clientId!, fullName: a.displayName),
        appointmentId: a.id,
        prefillIssue: a.title,
      ),
    ));
    if (created == true) {
      _refreshAfterAction();
      _snack('Orden de trabajo creada desde la cita.');
    }
  }

  Future<void> _delete(Appointment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cita'),
        content: Text('¿Eliminar la cita de ${a.displayName} a las ${a.time}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(agendaRepositoryProvider).delete(a.id);
      _refreshAfterAction();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  /// Normaliza el número para wa.me (solo dígitos; Bolivia si son 8 locales).
  String _waNumber(String phone) {
    var d = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('0')) d = d.substring(1);
    if (d.length == 8) d = '591$d';
    return d;
  }

  String _dateText(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${_dowFull[d.weekday - 1]} ${d.day} de ${_months[d.month - 1]}';
  }

  Future<void> _whatsapp(Appointment a) async {
    final phone = a.displayPhone;
    if (phone == null || phone.trim().isEmpty) {
      _snack('Este cliente no tiene teléfono registrado.');
      return;
    }
    final company = ref.read(authControllerProvider).me?.company?.name ?? '';
    final servicio =
        (a.title != null && a.title!.isNotEmpty) ? ' (${a.title})' : '';
    final msg =
        'Hola ${a.displayName}, le escribimos${company.isNotEmpty ? ' de $company' : ''} '
        'para confirmar su cita del ${_dateText(a.date)} a las ${a.time}$servicio. '
        '¿Podría confirmarnos, por favor?';
    final url = Uri.parse(
        'https://wa.me/${_waNumber(phone)}?text=${Uri.encodeComponent(msg)}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _snack('No se pudo abrir WhatsApp.');
    }
  }

  Future<void> _call(Appointment a) async {
    final phone = a.displayPhone;
    if (phone == null || phone.trim().isEmpty) {
      _snack('Este cliente no tiene teléfono registrado.');
      return;
    }
    final url = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');
    if (!await launchUrl(url)) {
      _snack('No se pudo iniciar la llamada.');
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));
}

Color _statusColor(String status) => switch (status) {
      'programada' => Colors.blue,
      'confirmada' => Colors.indigo,
      'completada' => Colors.green,
      'cancelada' => Colors.red,
      'no_asistio' => Colors.grey,
      _ => Colors.grey,
    };

class _RangeHeader extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _RangeHeader(
      {required this.label, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Text(label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  final DateTime weekStart;
  final DateTime selected;
  final void Function(DateTime) onPick;
  const _WeekStrip(
      {required this.weekStart, required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          for (int i = 0; i < 7; i++)
            Builder(builder: (context) {
              final d = weekStart.add(Duration(days: i));
              final isSel = d.year == selected.year &&
                  d.month == selected.month &&
                  d.day == selected.day;
              final isToday = d.year == today.year &&
                  d.month == today.month &&
                  d.day == today.day;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onPick(d),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(_dow[i],
                            style: TextStyle(
                                fontSize: 11,
                                color: isSel ? Colors.white70 : null)),
                        const SizedBox(height: 2),
                        Text('${d.day}',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isSel ? Colors.white : null)),
                        const SizedBox(height: 2),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isToday
                                ? (isSel ? Colors.white : Colors.red)
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _DayBody extends StatelessWidget {
  final AgendaDay day;
  final void Function(Appointment) onTap;
  final VoidCallback? onNew;
  const _DayBody({required this.day, required this.onTap, this.onNew});

  @override
  Widget build(BuildContext context) {
    if (day.appointments.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.event_available_outlined,
              size: 64, color: Colors.grey.withValues(alpha: .5)),
          const SizedBox(height: 12),
          const Center(child: Text('No hay citas para este día.')),
          const SizedBox(height: 12),
          if (onNew != null)
            Center(
              child: FilledButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add),
                label: const Text('Agendar una cita'),
              ),
            ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
      children: [
        Row(
          children: [
            _stat('Total', day.total, Colors.blueGrey),
            _stat('Program.', day.programada, Colors.blue),
            _stat('Confirm.', day.confirmada, Colors.indigo),
            _stat('Complet.', day.completada, Colors.green),
          ],
        ),
        const SizedBox(height: 12),
        for (final a in day.appointments)
          _ApptCard(appt: a, onTap: () => onTap(a)),
      ],
    );
  }

  Widget _stat(String label, int value, Color color) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text('$value',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18, color: color)),
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ),
      );
}

class _MonthCell extends StatelessWidget {
  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final int count;
  final VoidCallback onTap;
  const _MonthCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? primary.withValues(alpha: .12) : null,
          border: Border.all(
            color: isToday ? primary : Theme.of(context).dividerColor,
            width: isToday ? 1.5 : .5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${day.day}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  color: inMonth
                      ? (isToday ? primary : null)
                      : Colors.black38,
                )),
            const Spacer(),
            if (count > 0)
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 1),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(6),
                ),
                width: double.infinity,
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: primary)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ApptCard extends StatelessWidget {
  final Appointment appt;
  final VoidCallback onTap;
  const _ApptCard({required this.appt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(appt.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Text(appt.time,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  if (appt.endTime != null)
                    Text(appt.endTime!,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black45)),
                ],
              ),
              const SizedBox(width: 10),
              Container(width: 3, height: 42, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(appt.displayName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(appt.statusLabel,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text([
                      if (appt.title != null && appt.title!.isNotEmpty)
                        appt.title,
                      if (appt.vehicleLabel != null) appt.vehicleLabel,
                      if (appt.mechanicName != null) appt.mechanicName,
                      '${appt.durationMinutes} min',
                    ].whereType<String>().join(' · '),
                        style: const TextStyle(
                            fontSize: 12.5, color: Colors.black54)),
                    if (appt.workOrderId != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('OT creada',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
