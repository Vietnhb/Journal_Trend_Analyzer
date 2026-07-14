String formatCompactChartValue(num value) {
  final absoluteValue = value.abs();
  final prefix = value < 0 ? '-' : '';

  if (absoluteValue >= 1000000000) {
    return '$prefix${_trimDecimal(absoluteValue / 1000000000)}B';
  }
  if (absoluteValue >= 1000000) {
    return '$prefix${_trimDecimal(absoluteValue / 1000000)}M';
  }
  if (absoluteValue >= 1000) {
    return '$prefix${_trimDecimal(absoluteValue / 1000)}K';
  }
  return value.round().toString();
}

String formatExactChartValue(num value) {
  final rounded = value.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();

  if (rounded < 0) buffer.write('-');
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

double chartIntervalFor(double maximum, {int targetLines = 4}) {
  if (maximum <= 0 || targetLines <= 0) return 1;

  final roughInterval = maximum / targetLines;
  var magnitude = 1.0;
  while (roughInterval >= magnitude * 10) {
    magnitude *= 10;
  }
  while (roughInterval < magnitude) {
    magnitude /= 10;
  }

  final normalized = roughInterval / magnitude;
  final niceNormalized = switch (normalized) {
    <= 1 => 1.0,
    <= 2 => 2.0,
    <= 5 => 5.0,
    _ => 10.0,
  };
  return niceNormalized * magnitude;
}

double chartMaximumFor(double maximum, double interval) {
  if (maximum <= 0) return interval;
  return (maximum / interval).ceilToDouble() * interval;
}

String _trimDecimal(double value) {
  if (value >= 100 || value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}
