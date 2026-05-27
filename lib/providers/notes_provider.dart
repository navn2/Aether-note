import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';

// State Provider to hold search queries
final searchQueryProvider = StateProvider<String>((ref) => '');

// State Provider to hold selected tag filter
// null = All Notes
// '__pinned__' = Pinned Notes
// 'Work', 'Personal', etc. = custom tags
final selectedTagProvider = StateProvider<String?>((ref) => null);

// State Provider to hold theme mode (light, dark, system)
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

// State Provider to hold currently selected Note (used for Master-Detail view on desktop)
final activeNoteProvider = StateProvider<Note?>((ref) => null);
