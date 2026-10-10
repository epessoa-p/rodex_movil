/// Duraciones que se ofrecen al agendar (minutos → etiqueta). Hasta 5 días
/// para trabajos largos de taller. Igual que `Appointment::DURATIONS` (web).
const appointmentDurations = <int, String>{
  30: '30 min',
  60: '1 hora',
  90: '1 h 30 min',
  120: '2 horas',
  180: '3 horas',
  240: '4 horas',
  300: '5 horas',
  360: '6 horas',
  480: '8 horas (jornada)',
  1440: '1 día',
  2880: '2 días',
  4320: '3 días',
  5760: '4 días',
  7200: '5 días',
};

/// "45 min", "1 h 30 min", "2 días", "1 día 4 h".
String formatDuration(int minutes) {
  final days = minutes ~/ 1440;
  final hours = (minutes % 1440) ~/ 60;
  final mins = minutes % 60;
  final parts = [
    if (days > 0) '$days ${days == 1 ? 'día' : 'días'}',
    if (hours > 0) '$hours h',
    if (mins > 0) '$mins min',
  ];
  return parts.isEmpty ? '0 min' : parts.join(' ');
}

/// Fin de una cita de un día o más: "hasta jue 12/10 09:00" (null si dura menos).
String? multiDayEnd(String date, String time, int minutes) {
  if (minutes < 1440) return null;
  final start = DateTime.tryParse('${date}T$time:00');
  if (start == null) return null;
  final end = start.add(Duration(minutes: minutes));
  const days = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  String two(int v) => v.toString().padLeft(2, '0');
  return 'hasta ${days[end.weekday - 1]} ${two(end.day)}/${two(end.month)} '
      '${two(end.hour)}:${two(end.minute)}';
}
