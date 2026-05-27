import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:async';
import '../main.dart';
import '../data/database.dart';
import '../providers/notes_provider.dart';

// List of premium pastel colors for notes
// Structure: (LightModeColor, DarkModeColor, Name)
final List<(Color, Color, String)> noteColorPalette = [
  (Colors.transparent, Colors.transparent, 'Default'),
  (const Color(0xFFFFCDD2), const Color(0xFF5C2B2B), 'Red'),
  (const Color(0xFFFFE0B2), const Color(0xFF5C401B), 'Orange'),
  (const Color(0xFFFFF9C4), const Color(0xFF5C541B), 'Yellow'),
  (const Color(0xFFC8E6C9), const Color(0xFF1B5C25), 'Green'),
  (const Color(0xFFB3E5FC), const Color(0xFF1B4E5C), 'Blue'),
  (const Color(0xFFE1BEE7), const Color(0xFF451B5C), 'Purple'),
  (const Color(0xFFFFD180), const Color(0xFF5C331B), 'Amber'),
];

class EditorView extends ConsumerStatefulWidget {
  final Note? note;
  const EditorView({super.key, this.note});

  @override
  ConsumerState<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends ConsumerState<EditorView> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagInputController;

  int? _currentNoteId;
  DateTime? _createdAt;
  bool _isPinned = false;
  int _selectedColorIndex = 0;
  List<String> _tags = [];

  bool _isPreviewMode = false;
  bool _isAddingTag = false;
  String _saveStatus = 'Saved'; // 'Saved', 'Saving...', 'Unsaved changes'
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _tagInputController = TextEditingController();

    if (widget.note != null) {
      _currentNoteId = widget.note!.id;
      _createdAt = widget.note!.createdAt;
      _isPinned = widget.note!.isPinned;
      _selectedColorIndex = widget.note!.color;
      _tags = widget.note!.tags?.split(',').where((t) => t.isNotEmpty).toList() ?? [];
    }

    // Add listeners for auto-save
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.removeListener(_onTextChanged);
    _contentController.removeListener(_onTextChanged);
    _titleController.dispose();
    _contentController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  // Triggered on every keystroke
  void _onTextChanged() {
    setState(() {
      _saveStatus = 'Unsaved changes';
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), _autoSave);
  }

  // Background Auto-Save
  Future<void> _autoSave() async {
    if (!mounted) return;

    final titleText = _titleController.text.trim();
    final bodyText = _contentController.text;

    // Avoid saving empty notes
    if (titleText.isEmpty && bodyText.isEmpty) {
      setState(() {
        _saveStatus = 'Saved';
      });
      return;
    }

    setState(() {
      _saveStatus = 'Saving...';
    });

    final db = ref.read(databaseProvider);
    // Use first few words of body as title if empty
    final finalTitle = titleText.isEmpty
        ? (bodyText.split('\n').first.trim().isEmpty
            ? 'Untitled Note'
            : (bodyText.length > 30 ? '${bodyText.substring(0, 27)}...' : bodyText))
        : titleText;

    final tagsString = _tags.isEmpty ? null : _tags.join(',');

    try {
      if (_currentNoteId == null) {
        // Create new note
        final id = await db.insertNote(NotesCompanion(
          title: drift.Value(finalTitle),
          content: drift.Value(bodyText),
          isPinned: drift.Value(_isPinned),
          color: drift.Value(_selectedColorIndex),
          tags: drift.Value(tagsString),
          createdAt: drift.Value(DateTime.now()),
          updatedAt: drift.Value(DateTime.now()),
        ));
        _createdAt = DateTime.now();
        _currentNoteId = id;

        // Update selected note provider to keep focus
        final liveNote = Note(
          id: id,
          title: finalTitle,
          content: bodyText,
          createdAt: _createdAt!,
          updatedAt: DateTime.now(),
          isPinned: _isPinned,
          color: _selectedColorIndex,
          tags: tagsString,
        );
        ref.read(activeNoteProvider.notifier).state = liveNote;
      } else {
        // Update existing note
        final updatedNote = Note(
          id: _currentNoteId!,
          title: finalTitle,
          content: bodyText,
          createdAt: _createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
          isPinned: _isPinned,
          color: _selectedColorIndex,
          tags: tagsString,
        );
        await db.updateNote(updatedNote);
        ref.read(activeNoteProvider.notifier).state = updatedNote;
      }

      setState(() {
        _saveStatus = 'Saved';
      });
    } catch (e) {
      setState(() {
        _saveStatus = 'Error saving';
      });
    }
  }

  // Force Save & Exit (Mobile helper)
  void _forceSaveAndExit() async {
    _debounceTimer?.cancel();
    await _autoSave();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _togglePin() {
    setState(() {
      _isPinned = !_isPinned;
    });
    _onTextChanged();
  }

  void _addTag() {
    final newTag = _tagInputController.text.trim();
    if (newTag.isNotEmpty && !_tags.contains(newTag)) {
      setState(() {
        _tags.add(newTag);
        _tagInputController.clear();
        _isAddingTag = false;
      });
      _onTextChanged();
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
    _onTextChanged();
  }

  void _selectColor(int index) {
    setState(() {
      _selectedColorIndex = index;
    });
    _onTextChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark
        ? noteColorPalette[_selectedColorIndex].$2
        : noteColorPalette[_selectedColorIndex].$1;

    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 800;

    return Container(
      color: activeColor == Colors.transparent ? null : activeColor.withOpacity(isDark ? 0.35 : 0.8),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: isMobile
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _forceSaveAndExit,
                )
              : null,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _saveStatus == 'Saved'
                      ? Colors.green.withOpacity(0.1)
                      : (_saveStatus == 'Saving...'
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _saveStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _saveStatus == 'Saved'
                        ? Colors.green
                        : (_saveStatus == 'Saving...'
                            ? Colors.orange
                            : Colors.redAccent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            // Pin action
            IconButton(
              icon: Icon(
                _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: _isPinned ? Colors.amber : null,
              ),
              tooltip: 'Pin Note',
              onPressed: _togglePin,
            ),
            // Preview Toggle
            IconButton(
              icon: Icon(_isPreviewMode ? Icons.edit_outlined : Icons.menu_book_outlined),
              tooltip: _isPreviewMode ? 'Edit Note' : 'Preview Markdown',
              onPressed: () {
                setState(() {
                  _isPreviewMode = !_isPreviewMode;
                });
              },
            ),
            // Theme specific Color Palette picker
            PopupMenuButton<int>(
              icon: const Icon(Icons.palette_outlined),
              tooltip: 'Change Note Tint',
              onSelected: _selectColor,
              itemBuilder: (context) {
                return List.generate(noteColorPalette.length, (index) {
                  final colorTuple = noteColorPalette[index];
                  final colorVal = isDark ? colorTuple.$2 : colorTuple.$1;
                  return PopupMenuItem<int>(
                    value: index,
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: colorVal == Colors.transparent
                                ? (isDark ? Colors.grey[800] : Colors.grey[300])
                                : colorVal,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey, width: 0.5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(colorTuple.$3),
                      ],
                    ),
                  );
                });
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Title Editor
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: TextField(
                  controller: _titleController,
                  enabled: !_isPreviewMode,
                  decoration: const InputDecoration(
                    hintText: 'Give your note a title...',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),

              // Tags Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Icon(Icons.local_offer_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      ..._tags.map(
                        (tag) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Chip(
                            label: Text(tag, style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 12),
                            onDeleted: () => _removeTag(tag),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      if (_isAddingTag)
                        Container(
                          width: 120,
                          height: 28,
                          margin: const EdgeInsets.only(right: 6),
                          child: TextField(
                            controller: _tagInputController,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Tag name',
                              contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              border: OutlineInputBorder(),
                            ),
                            style: const TextStyle(fontSize: 12),
                            onSubmitted: (_) => _addTag(),
                          ),
                        )
                      else
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 14),
                          label: const Text('Add Tag', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setState(() {
                              _isAddingTag = true;
                            });
                          },
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24, thickness: 0.5, indent: 24, endIndent: 24),

              // Main body area (Markdown render or TextField)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _isPreviewMode
                      ? Markdown(
                          data: _contentController.text.isEmpty
                              ? '*No content written yet. Start typing to see Markdown preview.*'
                              : _contentController.text,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                        )
                      : TextField(
                          controller: _contentController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            hintText: 'Start writing in Markdown (# Header, **bold**, etc.)...',
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(fontSize: 16, height: 1.6),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
