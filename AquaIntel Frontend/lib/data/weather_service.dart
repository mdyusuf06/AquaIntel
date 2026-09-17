import 'package:dio/dio.dart';

class WeatherData {
  final double tempC;
  final double windSpeedKmh;
  final int windDirection; // degrees
  final double precipMm;
  final double visibilityM;
  final double? waveHeightM; // null when marine unavailable
  final double? waveDirectionDeg;

  const WeatherData({
    required this.tempC,
    required this.windSpeedKmh,
    required this.windDirection,
    required this.precipMm,
    required this.visibilityM,
    this.waveHeightM,
    this.waveDirectionDeg,
  });

  String get windCardinal {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((windDirection + 22) % 360) ~/ 45];
  }
}

class WeatherService {
  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Fetch weather + marine data for [lat]/[lon].
  static Future<WeatherData> fetch(double lat, double lon) async {
    // ── Atmospheric ───────────────────────────────────────────────────────
    final atm = await _dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': lat,
        'longitude': lon,
        'current':
            'temperature_2m,wind_speed_10m,wind_direction_10m,precipitation,visibility',
      },
    );
    final cur = atm.data['current'] as Map<String, dynamic>;

    // ── Marine (wave height/direction) ────────────────────────────────────
    double? waveH, waveD;
    try {
      final mar = await _dio.get(
        'https://marine-api.open-meteo.com/v1/marine',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'current': 'wave_height,wave_direction',
        },
      );
      final mc = mar.data['current'] as Map<String, dynamic>;
      waveH = (mc['wave_height'] as num?)?.toDouble();
      waveD = (mc['wave_direction'] as num?)?.toDouble();
    } catch (_) {
      // Marine API unavailable for inland coordinates — silently skip
    }

    return WeatherData(
      tempC: (cur['temperature_2m'] as num).toDouble(),
      windSpeedKmh: (cur['wind_speed_10m'] as num).toDouble(),
      windDirection: (cur['wind_direction_10m'] as num).toInt(),
      precipMm: (cur['precipitation'] as num).toDouble(),
      visibilityM: (cur['visibility'] as num?)?.toDouble() ?? 0,
      waveHeightM: waveH,
      waveDirectionDeg: waveD,
    );
  }
}
