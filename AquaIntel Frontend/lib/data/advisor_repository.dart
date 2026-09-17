import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/detection.dart';
import '../config.dart';

class AdvisorRepository {
  Future<String> ask(String prompt, List<Detection> detections) async {
    final payload = {
      'context': prompt, // Correctly pass the user prompt into the context key
      'detections': detections
          .map(
            (d) => {
              'id': d.id,
              'type': d.type,
              'risk_tier': d.riskTier,
              'confidence': d.confidence,
              'clearance_m': d.clearanceM,
              'height_m': d.heightM,
              'lat': d.lat,
              'lon': d.lon,
            },
          )
          .toList(),
    };

    final uri = Uri.parse('${AppConfig.baseUrl}/mission-advisor');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      // Safely read the 'action_plan' key returned by the FastAPI backend
      return (data['action_plan'] ??
              data['response'] ??
              data['answer'] ??
              data['text'] ??
              '')
          .toString();
    }
    throw Exception('Advisor API returned ${res.statusCode}');
  }
}
