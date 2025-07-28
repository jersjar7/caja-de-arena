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
      defaultValue:
          'pk.eyJ1IjoiamVyc29uZGV2cyIsImEiOiJjbTkxcGQ1emYwM2d1MnFwcWJ2dmgwYmpuIn0.ca52KhzP9gaK5nYDMv0ZxA', // Replace with your token
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
