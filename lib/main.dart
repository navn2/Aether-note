import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'data/database.dart';
import 'screens/dashboard_screen.dart';
import 'providers/notes_provider.dart';

// Global access to the Database
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

void main() {
  runApp(
    // ProviderScope enables Riverpod for the whole app
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch current theme mode
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Aether Note',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      
      // Modern Light Theme
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.outfitTextTheme(
          ThemeData.light().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      ),
      
      // Modern Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.outfitTextTheme(
          ThemeData.dark().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      ),
      
      home: const DashboardScreen(),
    );
  }
}
