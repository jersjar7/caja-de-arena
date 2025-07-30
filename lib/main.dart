import 'package:cupertino_showcase/pages/CupertinoRiverFavoritesPage.dart';
import 'package:cupertino_showcase/pages/CupertinoShortRangePage.dart';
import 'package:cupertino_showcase/pages/DarkModeRiverFlowChartPage.dart';
import 'package:cupertino_showcase/pages/RiverFlowChartPage.dart';
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
      // home: DarkModeRiverFlowChartPage(
      //   stationName: 'Default Station',
      //   rivername: 'Default River',
      // ),
      // home: CupertinoRiverFavoritesPage(),
      home: CupertinoShortRangePage(
        reachId: "31313421",
        riverName: "River",
        city: "City",
        state: "State",
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
