import os

frontend_dir = r"c:\Users\asus\Downloads\AquaIntel"

# 2. Add Visualizer Screen
visualizer_code = """import 'package:flutter/material.dart';
import 'package:three_dart/three_dart.dart' as three;
import 'package:three_dart/three3d/cameras/index.dart';
import 'package:three_dart/three3d/scenes/index.dart';
import 'package:flutter_gl/flutter_gl.dart';

class VisualizerScreen extends StatefulWidget {
  const VisualizerScreen({super.key});

  @override
  State<VisualizerScreen> createState() => _VisualizerScreenState();
}

class _VisualizerScreenState extends State<VisualizerScreen> {
  late FlutterGlPlugin flutterGlPlugin;
  three.Scene? scene;
  three.Camera? camera;
  three.WebGLRenderer? renderer;
  double? width;
  double? height;
  Size? screenSize;
  double dpr = 1.0;
  bool disposed = false;
  
  late three.Object3D object;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {}

  void initSize(BuildContext context) {
    if (screenSize != null) return;
    final mq = MediaQuery.of(context);
    screenSize = mq.size;
    dpr = mq.devicePixelRatio;
    initPlatformStatePlugin();
  }

  Future<void> initPlatformStatePlugin() async {
    width = screenSize!.width;
    height = screenSize!.height - 100; // Account for app bar etc.

    flutterGlPlugin = FlutterGlPlugin();
    Map<String, dynamic> options = {
      "antialias": true,
      "alpha": false,
      "width": width!.toInt(),
      "height": height!.toInt(),
      "dpr": dpr
    };
    await flutterGlPlugin.initialize(options: options);
    
    await Future.delayed(const Duration(milliseconds: 100));
    setupThreejs();
  }

  void setupThreejs() {
    options = {
      "width": width,
      "height": height,
      "gl": flutterGlPlugin.gl,
      "antialias": true,
      "canvas": flutterGlPlugin.element
    };
    renderer = three.WebGLRenderer(options);
    renderer!.setPixelRatio(dpr);
    renderer!.setSize(width, height, false);
    
    scene = three.Scene();
    scene!.background = three.Color.fromHex32(0x0F172A); // Dark bg
    
    camera = three.PerspectiveCamera(45, width! / height!, 1, 2000);
    camera!.position.z = 250;
    
    // Ambient Light
    final ambientLight = three.AmbientLight(0x404040, 2.0);
    scene!.add(ambientLight);
    
    final dirLight = three.DirectionalLight(0xffffff, 1.0);
    dirLight.position.set(100, 100, 50);
    scene!.add(dirLight);

    // Seafloor grid
    final gridHelper = three.GridHelper(400, 40, 0x3B9CF0, 0x334155);
    scene!.add(gridHelper);
    
    // Mock extruded bounding box (e.g. UXO or Debris)
    final geometry = three.BoxGeometry(20, 20, 20);
    final material = three.MeshPhongMaterial({"color": 0xEF4444}); // Red tier
    final cube = three.Mesh(geometry, material);
    cube.position.y = 10;
    scene!.add(cube);
    
    animate();
  }

  void animate() {
    if (!mounted || disposed) return;
    render();
    Future.delayed(const Duration(milliseconds: 16), () {
      animate();
    });
  }

  void render() {
    final gl = flutterGlPlugin.gl;
    renderer!.render(scene, camera);
    gl.flush();
    flutterGlPlugin.updateTexture(flutterGlPlugin.sourceTexture);
  }

  @override
  void dispose() {
    disposed = true;
    flutterGlPlugin.dispose();
    super.dispose();
  }

  Map<String, dynamic>? options;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D Seafloor Visualizer')),
      body: Builder(
        builder: (BuildContext context) {
          initSize(context);
          return SingleChildScrollView(
            child: _build(context)
          );
        },
      ),
    );
  }
  
  Widget _build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.black,
      child: flutterGlPlugin.isInitialized 
        ? Texture(textureId: flutterGlPlugin.textureId!) 
        : const Center(child: CircularProgressIndicator()),
    );
  }
}
"""

os.makedirs(os.path.join(frontend_dir, "lib", "screens", "visualizer"), exist_ok=True)
with open(os.path.join(frontend_dir, "lib", "screens", "visualizer", "visualizer_screen.dart"), "w", encoding="utf-8") as f:
    f.write(visualizer_code)

print("Created Visualizer Screen.")
