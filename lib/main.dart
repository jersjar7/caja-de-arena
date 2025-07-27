import 'package:flutter/cupertino.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'cupertino_showcase.dart';

void main() {
  // CRITICAL: Initialize Flutter bindings first
  WidgetsFlutterBinding.ensureInitialized();

  // Configure Mapbox access token
  MapboxOptions.setAccessToken(
    const String.fromEnvironment(
      'ACCESS_TOKEN',
      defaultValue: 'YOUR_MAPBOX_ACCESS_TOKEN_HERE', // Replace with your token
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Cupertino Widgets Demo',
      theme: CupertinoThemeData(primaryColor: CupertinoColors.systemBlue),
      home: CupertinoShowcase(),
      debugShowCheckedModeBanner: false,
    );
  }
}
