import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../data/api_client.dart';
import '../data/survey_repository.dart';
import '../data/weather_service.dart';
import '../models/load_state.dart';
import '../models/survey.dart';

class SurveyProvider extends ChangeNotifier {
  final SurveyRepository _repo;

  SurveyProvider(this._repo);

  List<Survey> _surveys = [];
  List<Vessel> _vessels = [];
  LoadState _state = LoadState.idle;
  String _error = '';
  bool _offlineMode = false;
  WeatherData? _weather;
  LoadState _weatherState = LoadState.idle;

  String _locationPermissionError = '';
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;

  List<Survey> get surveys => List.unmodifiable(_surveys);
  List<Vessel> get vessels => List.unmodifiable(_vessels);
  LoadState get state => _state;
  String get errorMessage => _error;
  bool get isLoading => _state == LoadState.loading;
  bool get offlineMode => _offlineMode;
  WeatherData? get weather => _weather;
  LoadState get weatherState => _weatherState;

  String get locationPermissionError => _locationPermissionError;
  Position? get currentPosition => _currentPosition;

  Survey? get activeSurvey {
    try {
      return _surveys.firstWhere((s) => s.status == 'in_progress');
    } catch (_) {
      return _surveys.isNotEmpty ? _surveys.first : null;
    }
  }

  Future<void> load() async {
    _state = LoadState.loading;
    _error = '';
    notifyListeners();

    try {
      _surveys = await _repo.getAll();
      _vessels = await _repo.getVessels();
      await _initLocationTracking();
      _state = LoadState.idle;
    } catch (e) {
      _state = LoadState.error;
      _error = e.toString();
    }
    notifyListeners();

    await _fetchWeather();
  }

  Future<void> _initLocationTracking() async {
    _locationPermissionError = '';

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationPermissionError = 'Location services are disabled.';
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _locationPermissionError = 'Location permission is denied.';
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _locationPermissionError =
            'Location permissions are permanently denied.';
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _currentPosition = position;
      _syncActiveSurveyLocation(position.latitude, position.longitude);

      await _positionStream?.cancel();
      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
            ),
          ).listen((Position pos) {
            _currentPosition = pos;
            _syncActiveSurveyLocation(pos.latitude, pos.longitude);
            notifyListeners();
          });
    } catch (e) {
      debugPrint('Geolocation initialization fallback: $e');
    }
  }

  void _syncActiveSurveyLocation(double lat, double lon) {
    if (_surveys.isEmpty) return;

    final idx = _surveys.indexWhere((s) => s.status == 'in_progress');
    final targetIdx = idx != -1 ? idx : 0;
    final s = _surveys[targetIdx];

    _surveys[targetIdx] = Survey(
      id: s.id,
      name: s.name,
      status: s.status,
      areaKm2: s.areaKm2,
      progressPct: s.progressPct,
      targetCount: s.targetCount,
      redAlertCount: s.redAlertCount,
      avgConfidence: s.avgConfidence,
      baseLat: lat,
      baseLon: lon,
    );
  }

  Future<void> startSurveyMission() async {
    _locationPermissionError = '';
    notifyListeners();

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationPermissionError =
            'Location permission is required to start a survey.';
        notifyListeners();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _currentPosition = pos;

      final surveyId = 'SV-${DateTime.now().millisecondsSinceEpoch}';
      final timestamp = DateTime.now().toIso8601String();

      // Register new survey in FastAPI backend SQLite database
      try {
        await ApiClient.instance.post(
          '/api/v1/surveys/start',
          data: {
            'survey_id': surveyId,
            'lat': pos.latitude,
            'lon': pos.longitude,
            'timestamp': timestamp,
          },
        );
      } catch (e) {
        debugPrint('Backend survey initialization skipped or offline: $e');
      }

      final newSurvey = Survey(
        id: surveyId,
        name: 'Survey ${DateTime.now().hour}:${DateTime.now().minute}',
        status: 'in_progress',
        areaKm2: 0.1,
        progressPct: 0.05,
        targetCount: 0,
        redAlertCount: 0,
        avgConfidence: 0.0,
        baseLat: pos.latitude,
        baseLon: pos.longitude,
      );

      _surveys = [newSurvey, ..._surveys];
      _syncActiveSurveyLocation(pos.latitude, pos.longitude);
      notifyListeners();

      await refreshWeather(pos.latitude, pos.longitude);
    } catch (e) {
      _locationPermissionError = 'Unable to determine device location: $e';
      notifyListeners();
    }
  }

  Future<void> _fetchWeather() async {
    double lat = 13.0827;
    double lon = 80.2707;

    if (_currentPosition != null) {
      lat = _currentPosition!.latitude;
      lon = _currentPosition!.longitude;
    } else if (activeSurvey != null && activeSurvey!.baseLat != 0.0) {
      lat = activeSurvey!.baseLat;
      lon = activeSurvey!.baseLon;
    }

    await refreshWeather(lat, lon);
  }

  Future<void> refreshWeather(double lat, double lon) async {
    _weatherState = LoadState.loading;
    notifyListeners();

    try {
      _weather = await WeatherService.fetch(lat, lon);
      _weatherState = LoadState.idle;
    } catch (e) {
      _weatherState = LoadState.error;
    }
    notifyListeners();
  }

  void toggleOfflineMode() {
    _offlineMode = !_offlineMode;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }
}
