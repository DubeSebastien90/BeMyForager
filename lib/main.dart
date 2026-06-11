import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const BeMyForagerApp());
}

class BeMyForagerApp extends StatelessWidget {
  const BeMyForagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeMyForager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
