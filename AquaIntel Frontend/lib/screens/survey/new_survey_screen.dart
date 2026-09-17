import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/survey_provider.dart';

/// New Survey flow screen:
/// - Auto Scan / Manual Upload toggle
/// - Live Learning promo banner
/// - Choose vessel (2-up cards)
/// - Debris focus chip grid
/// - Pinned black pill "Start survey" CTA
class NewSurveyScreen extends StatefulWidget {
  const NewSurveyScreen({super.key});

  @override
  State<NewSurveyScreen> createState() => _NewSurveyScreenState();
}

class _NewSurveyScreenState extends State<NewSurveyScreen> {
  int _modeIndex       = 0; // 0 = Auto Scan, 1 = Manual Upload
  int _selectedVessel  = 0;
  final Set<String> _selectedDebris = {'Ordnance', 'Wreck'};

  static const _modeLabels = ['Auto Scan', 'Manual Upload'];
  static const _debrisTypes = [
    'Ghost Net', 'Drum', 'Tire', 'Wreck',
    'Ordnance', 'Anchor', 'Pipe', 'Unknown',
  ];
  static const _highPriority = {'Ordnance', 'Wreck'};

  @override
  Widget build(BuildContext context) {
    final vessels = context.watch<SurveyProvider>().vessels;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
          onPressed: () => context.pop(),
        ),
        title: const Text('New Survey'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: const Divider(height: 1, color: Color(0xFFEBEBEB)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Scrollable content ────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                children: [

                  // ── Mode toggle ────────────────────────────────────────
                  Container(
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: List.generate(_modeLabels.length, (i) {
                        final isActive = _modeIndex == i;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _modeIndex = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFF0D0D0D) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _modeLabels[i],
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isActive ? Colors.white : const Color(0xFF8A8F98),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Live Learning promo banner ─────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1464C4).withValues(alpha: 0.055),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF1464C4).withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1464C4).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFF1464C4),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '20% faster with Live Learning',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1464C4),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Adaptive AI refines detection accuracy in real-time as you scan.',
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF8A8F98),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),

                  // ── Choose vessel ──────────────────────────────────────
                  Text(
                    'Choose vessel',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D0D0D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(min(vessels.length, 2), (i) {
                      final v = vessels[i];
                      final isSelected = _selectedVessel == i;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i == 0 ? 10 : 0),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedVessel = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF0D0D0D)
                                      : const Color(0xFFEBEBEB),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Type badge + check
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1464C4).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          v.type,
                                          style: GoogleFonts.manrope(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1464C4),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF0D0D0D),
                                          size: 18,
                                        ),
                                    ],
                                  ),

                                  // Vessel icon (representative visual)
                                  const SizedBox(height: 20),
                                  Center(
                                    child: Icon(
                                      Icons.directions_boat_filled_rounded,
                                      size: 40,
                                      color: isSelected
                                          ? const Color(0xFF0D0D0D)
                                          : const Color(0xFFCDD0D5),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Name
                                  Text(
                                    v.name,
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0D0D0D),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),

                                  // Sync status dot
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: v.syncStatus == 'synced'
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFFF59E0B),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        v.syncStatus == 'synced' ? 'Ready' : 'Syncing',
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          color: const Color(0xFF8A8F98),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 26),

                  // ── Debris focus ───────────────────────────────────────
                  Text(
                    'Debris focus',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D0D0D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _debrisTypes.map((type) {
                      final isSelected   = _selectedDebris.contains(type);
                      final isHighPri    = _highPriority.contains(type);

                      Color bgColor, borderColor, textColor;
                      if (isSelected && isHighPri) {
                        bgColor     = const Color(0xFFFEF2F2);
                        borderColor = const Color(0xFFEF4444);
                        textColor   = const Color(0xFFEF4444);
                      } else if (isSelected && !isHighPri) {
                        bgColor     = const Color(0xFF0D0D0D);
                        borderColor = const Color(0xFF0D0D0D);
                        textColor   = Colors.white;
                      } else {
                        bgColor     = Colors.white;
                        borderColor = const Color(0xFFEBEBEB);
                        textColor   = const Color(0xFF8A8F98);
                      }

                      return GestureDetector(
                        onTap: () => setState(() {
                          isSelected
                              ? _selectedDebris.remove(type)
                              : _selectedDebris.add(type);
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            type,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // ── Pinned Start Survey button ─────────────────────────────
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEBEBEB))),
              ),
              padding: EdgeInsets.fromLTRB(
                20, 14, 20,
                MediaQuery.of(context).padding.bottom + 14,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    final surProv = context.read<SurveyProvider>();
                    await surProv.startSurveyMission();
                    
                    if (!context.mounted) return;
                    
                    if (surProv.locationPermissionError.isNotEmpty) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Location Required'),
                          content: Text(surProv.locationPermissionError),
                          actions: [
                            TextButton(
                              onPressed: () => context.pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      context.go('/');
                    }
                  },
                  child: Text(
                    'Start survey',
                    style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
