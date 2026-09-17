import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/scan_result.dart';
import '../models/detection.dart';
import 'package:path/path.dart' as p;
import '../config.dart';

class UploadRepository {
  Future<ScanResult> upload(String filePath, {String? surveyId}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/upload-sonar');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    if (surveyId != null) {
      request.fields['survey_id'] = surveyId;
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final d = jsonDecode(response.body) as Map<String, dynamic>;
      final returnedSurveyId = d['survey_id']?.toString() ?? surveyId;
      final detectionsList = (d['detections'] as List?) ?? [];

      String? missionAdvisory;
      try {
        if (returnedSurveyId != null) {
          final sumRes = await http.get(
            Uri.parse(
              '${AppConfig.baseUrl}/surveys/$returnedSurveyId/summary',
            ),
          );
          if (sumRes.statusCode == 200) {
            final sumJson = jsonDecode(sumRes.body) as Map<String, dynamic>;
            final ma = sumJson['mission_advisory'];
            if (ma != null && ma is Map) {
              missionAdvisory =
                  "Identification Summary: ${ma['identification_summary']}\n\nEcological Impact: ${ma['ecological_impact']}\n\nAction Plan:\n${(ma['action_plan'] as List?)?.map((e) => "- $e").join('\n') ?? ''}";
            }
          }
        }
      } catch (e) {
        print('Summary fetch failed: $e');
      }

      return ScanResult(
        fileName: p.basename(filePath),
        uploadId: returnedSurveyId,
        isComplete: true,
        candidateCount: detectionsList.length,
        detectionCount: detectionsList.length,
        detections: detectionsList
            .map((x) => Detection.fromJson(x as Map<String, dynamic>))
            .toList(),
        missionAdvisory: missionAdvisory,
        towHeightM: 2.4,
        slantRangeM: 20.0,
        headingDeg: 90.0,
        resolutionMPerPx: 0.05,
      );
    }
    throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
  }
}
