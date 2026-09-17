import os

frontend_dir = r"c:\Users\asus\Downloads\AquaIntel"

map_screen_code = """import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/detection.dart';
import '../../providers/detection_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confidence_bar.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  void _showGlassBottomSheet(BuildContext context, Detection detection) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // Cropped Sonar Patch (Mock)
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.riskColor(detection.riskTier)),
                        ),
                        child: Icon(Icons.waves, color: AppTheme.riskColor(detection.riskTier), size: 40),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(detection.objectType, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 4),
                            Text('Height: ${detection.clearanceM}m', style: const TextStyle(fontSize: 14, color: Colors.white70)),
                            const SizedBox(height: 8),
                            ConfidenceBar(confidence: detection.confidence),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 16)
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 16)
                          ),
                          child: const Text('Verify'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16), // Safe area bottom
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Marker _buildMarker(Detection d) {
    return Marker(
      point: d.position,
      width: 40, height: 40,
      child: GestureDetector(
        onTap: () => _showGlassBottomSheet(context, d),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.riskColor(d.riskTier).withOpacity(0.8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: AppTheme.riskColor(d.riskTier).withOpacity(0.5), blurRadius: 8)],
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DetectionProvider>();
    final detections = prov.filteredDetections;

    return Scaffold(
      appBar: AppBar(title: const Text('Map View')),
      body: FlutterMap(
        options: const MapOptions(initialCenter: LatLng(45.524, -122.676), initialZoom: 14.5),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.aquaintel.app'),
          MarkerLayer(markers: detections.map((d) => _buildMarker(d)).toList()),
        ],
      ),
    );
  }
}
"""

with open(os.path.join(frontend_dir, "lib", "screens", "map", "map_screen.dart"), "w", encoding="utf-8") as f:
    f.write(map_screen_code)

print("Updated Map Screen.")
