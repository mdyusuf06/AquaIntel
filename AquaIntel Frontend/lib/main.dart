import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'data/detection_repository.dart';
import 'data/survey_repository.dart';
import 'data/upload_repository.dart';
import 'data/advisor_repository.dart';
import 'providers/detection_provider.dart';
import 'providers/survey_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/upload_provider.dart';
import 'theme/app_theme.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const AquaIntelApp());
}

class AquaIntelApp extends StatelessWidget {
  const AquaIntelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final p = DetectionProvider(ApiDetectionRepository());
          p.load(); // initial fetch
          return p;
        }),
        ChangeNotifierProvider(create: (_) {
          final p = SurveyProvider(ApiSurveyRepository());
          p.load(); // initial fetch + weather
          return p;
        }),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider(AdvisorRepository())),
        ChangeNotifierProvider(create: (_) => UploadProvider(UploadRepository())),
      ],
      child: Builder(
        builder: (context) => MaterialApp.router(
          title: 'AquaIntel',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: buildRouter(),
        ),
      ),
    );
  }
}
