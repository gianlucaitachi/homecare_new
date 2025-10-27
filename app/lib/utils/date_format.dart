import 'package:intl/intl.dart';

String formatDueDate(DateTime? date) {
  if (date == null) {
    return 'Không có hạn';
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDate = DateTime(date.year, date.month, date.day);

  if (dueDate.isAtSameMomentAs(today)) {
    return 'Hôm nay';
  }

  final formatted = DateFormat('dd/MM/yyyy').format(date);

  if (dueDate.isBefore(today)) {
    return 'Quá hạn: $formatted';
  }

  return formatted;
}
