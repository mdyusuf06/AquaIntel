import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiService {
  static String get baseUrl => AppConfig.baseUrl;

  Future<Map<String, dynamic>?> processSurvey(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/process-survey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print(
          'Error processing survey: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('Exception in processSurvey: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getMissionAdvice(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/mission-advisor'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print(
          'Error getting mission advice: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('Exception in getMissionAdvice: $e');
      return null;
    }
  }
}
