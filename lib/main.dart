import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:language_mixing_app/chat_screen.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  final apiKey = dotenv.env['GEMINI_API_KEY'];
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
        textTheme: GoogleFonts.notoSansJpTextTheme(),
        useMaterial3: true,
      ),
      home: ChatScreen(),
    );
  }
}
