import os

frontend_dir = r"c:\Users\asus\Downloads\AquaIntel"

home_screen_code = """import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/detection_provider.dart';
import '../../providers/survey_provider.dart';
import '../../widgets/detection_row.dart';
import '../../widgets/section_header.dart';
import '../../widgets/survey_card.dart';
import '../../data/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _activeFilter = 'All';
  final List<String> _filters = ['All', 'Red', 'Amber', 'Green'];
  bool isUploading = false;
  double uploadProgress = 0.0;

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() {});
  }
  
  void simulateUpload() async {
    setState(() {
      isUploading = true;
      uploadProgress = 0.0;
    });
    for(int i = 0; i <= 100; i += 10) {
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() {
        uploadProgress = i / 100.0;
      });
    }
    setState(() {
      isUploading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sonar log processed successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detProv = context.watch<DetectionProvider>();
    final surProv = context.watch<SurveyProvider>();
    final survey  = surProv.activeSurvey;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AquaIntel', style: Theme.of(context).textTheme.displayLarge),
                          const SizedBox(height: 4),
                          Text('Mission Dashboard', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Gradient Upload Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B9CF0), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Upload Sonar Logs', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Process new mission data through the risk engine', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 16),
                        if (isUploading) ...[
                          LinearProgressIndicator(value: uploadProgress, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation<Color>(Colors.white)),
                          const SizedBox(height: 8),
                          Text('${(uploadProgress * 100).toInt()}% Uploaded', style: const TextStyle(color: Colors.white)),
                        ] else
                          ElevatedButton.icon(
                            onPressed: simulateUpload,
                            icon: const Icon(Icons.cloud_upload),
                            label: const Text('Select File'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.3)),
                          )
                      ],
                    ),
                  ),
                ),
              ),
              
              // Quick filters
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _filters.map((f) {
                      bool isSelected = _activeFilter == f;
                      return ChoiceChip(
                        label: Text(f),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            _activeFilter = f;
                          });
                        },
                        selectedColor: Theme.of(context).primaryColor,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                      );
                    }).toList(),
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SectionHeader(title: 'Recent Detections', onSeeAll: () => context.go('/map')),
                ),
              ),
              
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = detProv.allDetections[index];
                      // Apply filter logic visually
                      if (_activeFilter != 'All' && item.riskTier.toLowerCase() != _activeFilter.toLowerCase()) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DetectionRow(detection: item),
                      );
                    },
                    childCount: detProv.allDetections.length,
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }
}
"""

with open(os.path.join(frontend_dir, "lib", "screens", "home", "home_screen.dart"), "w", encoding="utf-8") as f:
    f.write(home_screen_code)

print("Updated Home Screen.")
