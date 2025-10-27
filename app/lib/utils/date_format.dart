import 'package:intl/intl.dart';

String formatDueDate(DateTime? date) {
  if (date == null) {
    return 'No due date';
  }
  return DateFormat('MMM d, yyyy').format(date);
}
