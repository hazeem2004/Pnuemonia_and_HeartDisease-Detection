import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'services/ai_service.dart';
import 'services/location_service.dart';

void main() {
  runApp(const PneumoniaDetectorApp());
}

class PneumoniaDetectorApp extends StatelessWidget {
  const PneumoniaDetectorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AIService()),
        ChangeNotifierProvider(create: (context) => LocationService()),
      ],
      child: MaterialApp(
        title: 'Pneumonia Detector',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
          ),
        ),
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}