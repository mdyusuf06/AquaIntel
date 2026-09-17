import os

frontend_dir = r"c:\Users\asus\Downloads\AquaIntel"

# Fix main_shell.dart
path = os.path.join(frontend_dir, "lib", "screens", "shell", "main_shell.dart")
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
text = text.replace("Icons.3d_rotation", "Icons.view_in_ar_rounded")
with open(path, "w", encoding="utf-8") as f:
    f.write(text)

# Fix map_screen.dart
path = os.path.join(frontend_dir, "lib", "screens", "map", "map_screen.dart")
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
text = text.replace("detection.objectType", "detection.displayType")
text = text.replace("ConfidenceBar(confidence: detection.confidence)", "ConfidenceBar(value: detection.confidence)")
text = text.replace("point: d.position", "point: LatLng(d.lat, d.lon)")
with open(path, "w", encoding="utf-8") as f:
    f.write(text)

# Fix home_screen.dart
path = os.path.join(frontend_dir, "lib", "screens", "home", "home_screen.dart")
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
text = text.replace("SectionHeader(title: 'Recent Detections', onSeeAll: () => context.go('/map'))", "SectionHeader(title: 'Recent Detections')")
with open(path, "w", encoding="utf-8") as f:
    f.write(text)

# We will replace visualizer_screen.dart with a simplified WebView or placeholder if flutter_gl fails, but let's just fix the flutter_gl API issues.
path = os.path.join(frontend_dir, "lib", "screens", "visualizer", "visualizer_screen.dart")
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
text = text.replace("renderer!.setSize(width, height, false);", "renderer!.setSize(width!, height!, false);")
text = text.replace("three.Color.fromHex32(0x0F172A)", "three.Color(0, 0, 0)")
text = text.replace("renderer!.render(scene, camera);", "renderer!.render(scene!, camera!);")
text = text.replace("flutterGlPlugin.updateTexture(flutterGlPlugin.sourceTexture);", "if (flutterGlPlugin.textureId != null) flutterGlPlugin.updateTexture(flutterGlPlugin.textureId!);")
with open(path, "w", encoding="utf-8") as f:
    f.write(text)

# Add flutter_gl to pubspec.yaml
pubspec_path = os.path.join(frontend_dir, "pubspec.yaml")
with open(pubspec_path, "r", encoding="utf-8") as f:
    text = f.read()
if "flutter_gl:" not in text:
    text = text.replace("three_dart: any", "three_dart: any\n  flutter_gl: any")
with open(pubspec_path, "w", encoding="utf-8") as f:
    f.write(text)

print("Fixes applied.")
