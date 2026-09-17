import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get baseUrl => dotenv.env['AQUAINTEL_API_URL'] ?? 'http://192.168.1.4:8000';
}
