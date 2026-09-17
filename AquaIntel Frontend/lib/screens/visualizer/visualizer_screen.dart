import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:flutter/services.dart';
import '../../data/api_client.dart'; // Import your network client

class VisualizerScreen extends StatefulWidget {
  final String? targetId;
  const VisualizerScreen({super.key, this.targetId});

  @override
  State<VisualizerScreen> createState() => _VisualizerScreenState();
}

class _VisualizerScreenState extends State<VisualizerScreen> {
  final _controller = WebviewController();
  bool _isWebviewInitialized = false;

  @override
  void initState() {
    super.initState();
    initWebview();
  }

  Future<void> initWebview() async {
    try {
      await _controller.initialize();
      final html = await rootBundle.loadString('assets/3d_viewer.html');
      await _controller.loadStringContent(html);

      setState(() {
        _isWebviewInitialized = true;
      });

      if (widget.targetId != null) {
        _loadTarget3DData();
      }
    } catch (e) {
      debugPrint('Webview initialization failed: $e');
    }
  }

  Future<void> _loadTarget3DData() async {
    try {
      // Live API call to FastAPI backend using your local IPv4 address
      final res = await ApiClient.instance.get(
        '/detections/${widget.targetId}/heightmap',
      );
      final data = res.data;

      // Extract real physics data and OpenCV base64 heightmap
      final b64 = data['heightmap_base64'];
      final width = data['width_m'];
      final length = data['length_m'];
      final height = data['height_m'];

      // Inject directly into the Three.js JavaScript context
      _controller.executeScript(
        'window.loadHeightmap("$b64", $width, $length, $height);',
      );
    } catch (e) {
      debugPrint('Failed to load 3D target data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('3D Sonar Viewer ${widget.targetId ?? ''}'),
        backgroundColor: const Color(0xFF0D1117),
        foregroundColor: Colors.white,
      ),
      body: _isWebviewInitialized
          ? Webview(_controller)
          : const Center(child: CircularProgressIndicator()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
