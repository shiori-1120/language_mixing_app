import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:language_mixing_app/chat_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
);
  final apiKey = dotenv.get('GEMINI_API_KEY');
  if (apiKey == null || apiKey.isEmpty) {
    print('No \$API_KEY environment variable');
    exit(1);
  }
  runApp(ProviderScope(child: RooChatApp()));
}

class RooChatApp extends StatelessWidget {
  const RooChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'いい感じのルー大柴',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: ChatScreen(),
    );
  }
}
