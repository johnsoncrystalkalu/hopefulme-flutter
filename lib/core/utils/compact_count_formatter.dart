String formatCompactCount(int value) {
  if (value >= 1000000) {
    final compact = value / 1000000;
    return compact >= 10
        ? '${compact.toStringAsFixed(0)}m'
        : '${compact.toStringAsFixed(1)}m'.replaceAll('.0m', 'm');
  }
  if (value >= 100000) {
    final compact = value / 100000;
    return compact >= 10
        ? '${compact.toStringAsFixed(0)}l'
        : '${compact.toStringAsFixed(1)}l'.replaceAll('.0l', 'l');
  }
  if (value >= 1000) {
    final compact = value / 1000;
    return compact >= 10
        ? '${compact.toStringAsFixed(0)}k'
        : '${compact.toStringAsFixed(1)}k'.replaceAll('.0k', 'k');
  }
  return value.toString();
}
