import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/scan_result.dart';
import '../models/detection.dart';
import '../data/upload_repository.dart';
import '../config.dart';

class UploadProvider extends ChangeNotifier {
  final UploadRepository _repo;
  UploadProvider(this._repo);

  ScanResult? _result;
  bool _isPicking = false;

  ScanResult? get result => _result;
  bool get isPicking => _isPicking;
  bool get isIdle => _result == null;
  bool get isRunning =>
      _result != null && !_result!.isComplete && !_result!.hasError;

  void reset() {
    _result = null;
    notifyListeners();
  }

  Future<void> startMockUpload(String fileName) async {
    _result = ScanResult(fileName: fileName);
    notifyListeners();

    final steps = PipelineStep.values;
    final elapsed = <PipelineStep, Duration>{};
    final progress = <PipelineStep, double>{};

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final stepStart = DateTime.now();

      // Mark step as active
      _result = _result!.copyWith(
        activeStep: step,
        stepProgress: Map.from(progress),
        stepElapsed: Map.from(elapsed),
      );
      notifyListeners();

      // Simulate progress ticks
      for (int p = 0; p <= 100; p += 5) {
        await Future.delayed(const Duration(milliseconds: 60));
        if (_result == null) return; // Cancelled
        progress[step] = p / 100.0;
        elapsed[step] = DateTime.now().difference(stepStart);
        _result = _result!.copyWith(
          stepProgress: Map.from(progress),
          stepElapsed: Map.from(elapsed),
        );
        notifyListeners();
      }

      elapsed[step] = DateTime.now().difference(stepStart);
      _result = _result!.copyWith(
        completedSteps: i + 1,
        stepProgress: Map.from(progress),
        stepElapsed: Map.from(elapsed),
      );
      notifyListeners();
    }

    // Done
    _result = _result!.copyWith(
      isComplete: true,
      activeStep: null,
      candidateCount: 12,
      detectionCount: 7,
      towHeightM: 2.4,
      slantRangeM: 75.0,
      headingDeg: 214.5,
      resolutionMPerPx: 0.1,
      missionAdvisory: "Identification Summary: High-risk debris field identified.\n\nEcological Impact: Ghost nets pose a severe entanglement risk to local marine life, potentially causing long-term damage to the reef ecosystem.\n\nAction Plan:\n1. Deploy ROV to verify net position.\n2. Coordinate with local authorities for safe removal.\n3. Monitor area for secondary hazards.",
      detections: [
        Detection.fromJson({
          "id": "mock_id_1",
          "object_type": "Ghost fishing net",
          "lat": 13.0,
          "lon": 80.0,
          "clearance_m": 8.5,
          "risk_tier": "red",
          "impact_profile": {"impact_severity": "High", "impact_type": "Entanglement hazard"},
          "confidence": 0.87
        })
      ],
    );
    notifyListeners();
  }

  Future<void> startBackendUpload(String fileName) async {
    _result = ScanResult(fileName: fileName);
    notifyListeners();

    final steps = PipelineStep.values;
    final elapsed = <PipelineStep, Duration>{};
    final progress = <PipelineStep, double>{};
    bool futureCompleted = false;
    ScanResult? uploadResult;
    String? errorMsg;

    // 1. Generate survey ID and start survey
    final String surveyId = const Uuid().v4();
    double lat = 0.0;
    double lon = 0.0;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, 
          timeLimit: Duration(seconds: 3),
        ),
      );
      lat = pos.latitude;
      lon = pos.longitude;
    } catch (_) {
      print('Could not fetch GPS, using 0,0');
    }

    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/surveys/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'survey_id': surveyId,
          'lat': lat,
          'lon': lon,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      print('Failed to start survey on backend: $e');
    }

    // Start background HTTP upload
    _repo.upload(fileName, surveyId: surveyId).then((res) {
      uploadResult = res;
      futureCompleted = true;
    }).catchError((e) {
      errorMsg = e.toString();
      futureCompleted = true;
    });

    // Concurrently animate steps until upload finishes
    for (int i = 0; i < steps.length - 1; i++) {
      if (futureCompleted) break;
      final step = steps[i];
      final stepStart = DateTime.now();
      
      _result = _result!.copyWith(
        activeStep: step,
        stepProgress: Map.from(progress),
        stepElapsed: Map.from(elapsed),
      );
      notifyListeners();
      
      for (int p = 0; p <= 100; p += 20) {
        if (futureCompleted) break;
        await Future.delayed(const Duration(milliseconds: 100));
        progress[step] = p / 100.0;
        elapsed[step] = DateTime.now().difference(stepStart);
        _result = _result!.copyWith(
          stepProgress: Map.from(progress),
          stepElapsed: Map.from(elapsed),
        );
        notifyListeners();
      }
      
      progress[step] = 1.0;
      elapsed[step] = DateTime.now().difference(stepStart);
      _result = _result!.copyWith(
        completedSteps: i + 1,
        stepProgress: Map.from(progress),
        stepElapsed: Map.from(elapsed),
      );
      notifyListeners();
    }

    // Wait for actual backend response if animation finished early
    while (!futureCompleted) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (errorMsg != null) {
      _result = _result!.copyWith(hasError: true, errorMessage: errorMsg);
    } else if (uploadResult != null) {
      _result = uploadResult!.copyWith(
        completedSteps: steps.length,
        stepProgress: _result!.stepProgress,
        stepElapsed: _result!.stepElapsed,
      );
    }
    notifyListeners();
  }
}
