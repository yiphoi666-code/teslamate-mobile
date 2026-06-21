String formatDate(DateTime value) {
  if (value.millisecondsSinceEpoch <= 0) {
    return 'No data';
  }

  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}

String formatDuration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  if (hours == 0) {
    return '${minutes}m';
  }
  return '${hours}h ${minutes}m';
}

String formatMoney(double value) => '\$${value.toStringAsFixed(2)}';
