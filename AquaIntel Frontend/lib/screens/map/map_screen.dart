import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

import '../../models/detection.dart';
import '../../models/load_state.dart';
import '../../providers/detection_provider.dart';
import '../../providers/survey_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/aq_button.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  bool _showPins = false;

  SurveyProvider? _surveyProvider;
  Position? _lastPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DetectionProvider>().load();
      _surveyProvider = context.read<SurveyProvider>();
      _surveyProvider?.addListener(_onSurveyUpdate);
    });
  }

  void _onSurveyUpdate() {
    if (_surveyProvider?.currentPosition != null && _surveyProvider?.currentPosition != _lastPosition) {
      _lastPosition = _surveyProvider!.currentPosition;
      _mapController.move(LatLng(_lastPosition!.latitude, _lastPosition!.longitude), _mapController.camera.zoom);
    }
  }

  @override
  void dispose() {
    _surveyProvider?.removeListener(_onSurveyUpdate);
    super.dispose();
  }

  void _showDetailSheet(Detection d) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E).withValues(alpha: 0.92),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: AppSpacing.s24),
                  Row(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.riskBg(d.riskTier),
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          border: Border.all(color: AppTheme.riskColor(d.riskTier).withValues(alpha: 0.5)),
                          boxShadow: [BoxShadow(color: AppTheme.riskColor(d.riskTier).withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 4)],
                        ),
                        child: Icon(Icons.waves_rounded, color: AppTheme.riskColor(d.riskTier), size: 40),
                      ),
                      const SizedBox(width: AppSpacing.s16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.displayType, style: AppTextStyles.title.copyWith(color: Colors.white)),
                            const SizedBox(height: AppSpacing.s4),
                            Text('${d.clearanceM.toStringAsFixed(1)}m depth clearance', style: AppTextStyles.bodySecondary.copyWith(color: Colors.white60)),
                            const SizedBox(height: AppSpacing.s8),
                            Row(
                              children: [
                                Text('${(d.confidence * 100).toStringAsFixed(0)}%', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                                const SizedBox(width: AppSpacing.s8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                    child: LinearProgressIndicator(
                                      value: d.confidence,
                                      backgroundColor: AppColors.lightBlue.withValues(alpha: 0.3),
                                      color: AppColors.primaryBlue,
                                      minHeight: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  // Info grid
                  _InfoGrid(detection: d),
                  const SizedBox(height: AppSpacing.s24),
                  Row(
                    children: [
                      Expanded(
                        child: AqButton(
                          label: 'Reject',
                          type: AqButtonType.secondary,
                          isFullWidth: true,
                          onPressed: () { context.read<DetectionProvider>().reject(d.id); Navigator.pop(context); },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s16),
                      Expanded(
                        child: AqButton(
                          label: 'Verify',
                          isFullWidth: true,
                          onPressed: () { context.read<DetectionProvider>().verify(d.id); Navigator.pop(context); },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Marker _buildMarker(Detection d) => Marker(
    point: LatLng(d.lat, d.lon),
    width: 52, height: 52,
    child: GestureDetector(
      onTap: () => _showDetailSheet(d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.elasticOut,
        decoration: BoxDecoration(
          color: AppTheme.riskColor(d.riskTier),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(color: AppTheme.riskColor(d.riskTier).withValues(alpha: 0.6), blurRadius: 16, spreadRadius: 3),
          ],
        ),
        child: Icon(_markerIcon(d.type), color: Colors.white, size: 22),
      ),
    ),
  );

  IconData _markerIcon(String type) {
    if (type.contains('uxo') || type.contains('mine')) return Icons.dangerous_rounded;
    if (type.contains('drum') || type.contains('barrel')) return Icons.water_drop_outlined;
    if (type.contains('net') || type.contains('ghost')) return Icons.grain_rounded;
    return Icons.location_on;
  }

  // Replaced concentric rings with custom HeatmapLayer

  LatLng _centerPoint(SurveyProvider surProv, DetectionProvider detProv) {
    final s = surProv.activeSurvey;
    if (s != null && s.baseLat != 0.0) return LatLng(s.baseLat, s.baseLon);
    final dets = detProv.allDetections;
    if (dets.isNotEmpty) {
      final lat = dets.map((d) => d.lat).reduce((a, b) => a + b) / dets.length;
      final lon = dets.map((d) => d.lon).reduce((a, b) => a + b) / dets.length;
      return LatLng(lat, lon);
    }
    // Coastal Chennai / survey origin fallback
    return const LatLng(13.0827, 80.2707);
  }

  @override
  Widget build(BuildContext context) {
    final detProv = context.watch<DetectionProvider>();
    final surProv = context.watch<SurveyProvider>();
    final center  = _centerPoint(surProv, detProv);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: 14.5),
            children: [
              // Inverted OpenStreetMap tiles for keyless dark mode
              ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  -1.0, 0.0, 0.0, 0.0, 255.0,
                  0.0, -1.0, 0.0, 0.0, 255.0,
                  0.0, 0.0, -1.0, 0.0, 255.0,
                  0.0, 0.0, 0.0, 1.0, 0.0,
                ]),
                child: TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.aquaintel.app',
                  errorTileCallback: (tile, error, stackTrace) {},
                ),
              ),
              // Heatmap overlay
              if (detProv.filteredDetections.isNotEmpty)
                HeatmapLayer(detections: detProv.filteredDetections),
              // Detection markers toggle
              if (_showPins && detProv.allDetections.isNotEmpty)
                MarkerLayer(
                  markers: detProv.filteredDetections.map(_buildMarker).toList(),
                ),
                
              // Live GPS Self Marker
              if (surProv.currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(surProv.currentPosition!.latitude, surProv.currentPosition!.longitude),
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.5), blurRadius: 12)],
                        ),
                        child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Top gradient for safe area
          Positioned(
            top: 0, left: 0, right: 0, height: 130,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                ),
              ),
            ),
          ),

          // Bottom gradient to ensure no content clips behind nav bar
          Positioned(
            bottom: 0, left: 0, right: 0, height: 110,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.3), Colors.transparent],
                ),
              ),
            ),
          ),

          // Floating Controls — inset above bottom nav
          Positioned(
            top: 140, right: AppSpacing.s24,
            child: Column(
              children: [
                _MapControlButton(
                  icon: _showPins ? Icons.location_on : Icons.layers_outlined,
                  active: _showPins,
                  onTap: () => setState(() => _showPins = !_showPins),
                ),
                const SizedBox(height: AppSpacing.s12),
                _MapControlButton(
                  icon: Icons.my_location_rounded,
                  onTap: () {
                    if (surProv.currentPosition != null) {
                      _mapController.move(
                        LatLng(surProv.currentPosition!.latitude, surProv.currentPosition!.longitude),
                        _mapController.camera.zoom,
                      );
                    } else {
                      _mapController.move(center, 14.5);
                    }
                  },
                ),
              ],
            ),
          ),

          // Risk legend — bottom left, with bottom padding
          Positioned(
            bottom: 100, left: AppSpacing.s16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F2E).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LegendRow(color: const Color(0xFFEF4444), label: 'High Risk'),
                  const SizedBox(height: AppSpacing.s6),
                  _LegendRow(color: const Color(0xFFF59E0B), label: 'Moderate'),
                  const SizedBox(height: AppSpacing.s6),
                  _LegendRow(color: const Color(0xFF10B981), label: 'Clear'),
                ],
              ),
            ),
          ),

          // Detection count badge — bottom right, with bottom padding
          Positioned(
            bottom: 100, right: AppSpacing.s16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F2E).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.radar_rounded, color: AppColors.primaryBlue, size: 16),
                  const SizedBox(width: AppSpacing.s6),
                  Text('${detProv.filteredDetections.length} targets', style: AppTextStyles.caption.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (detProv.isLoading)
            Positioned(
              top: 60, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24, vertical: AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2E),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue)),
                      const SizedBox(width: AppSpacing.s12),
                      Text('Loading detections...', style: AppTextStyles.body.copyWith(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),

          // Error banner (Network)
          if (detProv.state == LoadState.error)
            Positioned(
              top: 60, left: AppSpacing.s24, right: AppSpacing.s24,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 24),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(child: Text(detProv.errorMessage, style: AppTextStyles.body.copyWith(color: AppColors.danger))),
                  GestureDetector(
                    onTap: detProv.load,
                    child: Text('Retry', style: AppTextStyles.body.copyWith(color: AppColors.danger, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
            ),
            
          // Permission banner
          if (surProv.locationPermissionError.isNotEmpty)
            Positioned(
              top: 140, left: AppSpacing.s24, right: AppSpacing.s24,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: const Color(0xFF332200), // Warning Orange Dark
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 24),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(child: Text(surProv.locationPermissionError, style: AppTextStyles.body.copyWith(color: Colors.orangeAccent))),
                ]),
              ),
            ),
          // Survey Summary Header
          if (surProv.activeSurvey != null)
            Positioned(
              top: 50, left: AppSpacing.s24, right: AppSpacing.s24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2E).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: AppShadows.soft,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s8),
                      decoration: BoxDecoration(
                        color: AppTheme.riskBg(surProv.activeSurvey!.redAlertCount > 0 ? 'red' : 'green'),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.radar, color: AppTheme.riskColor(surProv.activeSurvey!.redAlertCount > 0 ? 'red' : 'green'), size: 20),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active Survey: ${surProv.activeSurvey!.name}', style: AppTextStyles.bodyLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('${DateTime.now().toLocal().toString().split(' ')[0]} ∙ ${detProv.filteredDetections.length} detections', style: AppTextStyles.caption.copyWith(color: Colors.white60)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final Detection detection;
  const _InfoGrid({required this.detection});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _InfoCell(label: 'Depth', value: '${detection.clearanceM.toStringAsFixed(1)}m'),
        _InfoCell(label: 'Confidence', value: '${(detection.confidence * 100).toStringAsFixed(0)}%'),
        _InfoCell(label: 'Risk', value: detection.riskTier.toUpperCase()),
        _InfoCell(label: 'ID', value: detection.id),
      ],
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label, value;
  const _InfoCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s8),
        margin: const EdgeInsets.only(right: AppSpacing.s8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Column(
          children: [
            Text(label, style: AppTextStyles.caption.copyWith(color: Colors.white38)),
            const SizedBox(height: 2),
            Text(value, style: AppTextStyles.bodyLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)])),
        const SizedBox(width: AppSpacing.s8),
        Text(label, style: AppTextStyles.caption.copyWith(color: Colors.white70)),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _MapControlButton({required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: active ? AppColors.primaryBlue : const Color(0xFF1A1F2E).withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(color: active ? Colors.transparent : Colors.white.withValues(alpha: 0.15)),
          boxShadow: AppShadows.soft,
        ),
        child: Icon(icon, color: active ? Colors.white : Colors.white70),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<Detection> detections;
  final MapCamera camera;
  
  _HeatmapPainter(this.detections, this.camera);
  
  @override
  void paint(Canvas canvas, Size size) {
    for (final d in detections) {
      final offset = camera.getOffsetFromOrigin(LatLng(d.lat, d.lon));
      
      double weight = 0.2;
      Color color = const Color(0xFF10B981); // Green
      if (d.riskTier == 'red') {
        weight = 1.0;
        color = const Color(0xFFEF4444);
      } else if (d.riskTier == 'amber') {
        weight = 0.6;
        color = const Color(0xFFF59E0B);
      }
      
      final radius = 90.0 * weight;
      if (radius <= 0) continue;
      
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.5 * weight),
            color.withValues(alpha: 0.2 * weight),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: offset, radius: radius))
        ..blendMode = BlendMode.screen;
        
      canvas.drawCircle(offset, radius, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) => true;
}

class HeatmapLayer extends StatelessWidget {
  final List<Detection> detections;
  const HeatmapLayer({super.key, required this.detections});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return CustomPaint(
      size: Size.infinite,
      painter: _HeatmapPainter(detections, camera),
    );
  }
}
