import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../main.dart';
import '../data/database.dart';
import '../providers/notes_provider.dart';
import 'editor_view.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 900;

    // Get the database stream
    final database = ref.watch(databaseProvider);

    return StreamBuilder<List<Note>>(
      stream: database.watchAllNotes(),
      builder: (context, snapshot) {
        final allNotes = snapshot.data ?? [];

        // Dynamic unique tags calculation
        final allTagsSet = <String>{};
        for (var note in allNotes) {
          if (note.tags != null && note.tags!.isNotEmpty) {
            final split = note.tags!.split(',');
            for (var t in split) {
              if (t.trim().isNotEmpty) {
                allTagsSet.add(t.trim());
              }
            }
          }
        }
        final dynamicTags = allTagsSet.toList()..sort();

        // Perform search & tag filtering in memory for perfect reactivity
        final query = ref.watch(searchQueryProvider).toLowerCase();
        final selectedTag = ref.watch(selectedTagProvider);

        final filteredNotes = allNotes.where((note) {
          // Tag Filter
          if (selectedTag != null) {
            if (selectedTag == '__pinned__') {
              if (!note.isPinned) return false;
            } else {
              final noteTags = note.tags?.split(',').map((t) => t.trim()).toList() ?? [];
              if (!noteTags.contains(selectedTag)) return false;
            }
          }

          // Search Filter
          if (query.isNotEmpty) {
            final titleMatch = note.title.toLowerCase().contains(query);
            final contentMatch = note.content?.toLowerCase().contains(query) ?? false;
            final tagsMatch = note.tags?.toLowerCase().contains(query) ?? false;
            return titleMatch || contentMatch || tagsMatch;
          }

          return true;
        }).toList();

        if (isDesktop) {
          return _buildDesktopLayout(context, ref, filteredNotes, dynamicTags, allNotes.length);
        } else {
          return _buildMobileLayout(context, ref, filteredNotes, dynamicTags, allNotes.length);
        }
      },
    );
  }

  // --- DESKTOP LAYOUT (3 columns) ---
  Widget _buildDesktopLayout(
    BuildContext context,
    WidgetRef ref,
    List<Note> notes,
    List<String> tags,
    int totalCount,
  ) {
    final activeNote = ref.watch(activeNoteProvider);

    return Scaffold(
      body: Row(
        children: [
          // Column 1: Navigation Sidebar
          _buildSidebar(context, ref, tags, totalCount),
          const VerticalDivider(width: 0.5, thickness: 0.5),

          // Column 2: Notes Grid & Search
          Container(
            width: 380,
            color: Theme.of(context).cardColor.withOpacity(0.3),
            child: Column(
              children: [
                _buildSearchBar(context, ref),
                Expanded(
                  child: _buildNotesGrid(context, ref, notes, false),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 0.5, thickness: 0.5),

          // Column 3: Active Editor Pane
          Expanded(
            child: activeNote == null
                ? _buildEmptyStateEditor(context, ref)
                : EditorView(
                    key: ValueKey('desktop_editor_${activeNote.id}'),
                    note: activeNote,
                  ),
          ),
        ],
      ),
    );
  }

  // --- MOBILE LAYOUT (Stack/Navigator based) ---
  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    List<Note> notes,
    List<String> tags,
    int totalCount,
  ) {
    final selectedTag = ref.watch(selectedTagProvider);
    String headerTitle = 'All Notes';
    if (selectedTag == '__pinned__') {
      headerTitle = 'Pinned';
    } else if (selectedTag != null) {
      headerTitle = '# $selectedTag';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(headerTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      drawer: Drawer(
        child: SafeArea(
          child: _buildSidebar(context, ref, tags, totalCount),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(context, ref),
          Expanded(
            child: _buildNotesGrid(context, ref, notes, true),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNoteEditor(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- COMPONENT: Sidebar ---
  Widget _buildSidebar(
    BuildContext context,
    WidgetRef ref,
    List<String> tags,
    int totalCount,
  ) {
    final selectedTag = ref.watch(selectedTagProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 250,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Branding Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.cyan, Colors.purpleAccent],
                  ).createShader(bounds),
                  child: const Icon(
                    Icons.bubble_chart,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Aether Note',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // Primary Sidebar Items
          _SidebarItem(
            icon: Icons.notes_outlined,
            title: 'All Notes',
            count: totalCount,
            isSelected: selectedTag == null,
            onTap: () {
              ref.read(selectedTagProvider.notifier).state = null;
              // Close drawer if on mobile
              if (MediaQuery.of(context).size.width < 900) {
                Navigator.pop(context);
              }
            },
          ),
          _SidebarItem(
            icon: Icons.push_pin_outlined,
            title: 'Pinned Notes',
            isSelected: selectedTag == '__pinned__',
            onTap: () {
              ref.read(selectedTagProvider.notifier).state = '__pinned__';
              if (MediaQuery.of(context).size.width < 900) {
                Navigator.pop(context);
              }
            },
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              'TAGS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
          ),

          // Dynamic Tags list
          Expanded(
            child: tags.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'No tags yet. Add tags inside your notes to see them here.',
                      style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                    ),
                  )
                : ListView.builder(
                    itemCount: tags.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final t = tags[index];
                      return _SidebarItem(
                        icon: Icons.tag,
                        title: t,
                        isSelected: selectedTag == t,
                        onTap: () {
                          ref.read(selectedTagProvider.notifier).state = t;
                          if (MediaQuery.of(context).size.width < 900) {
                            Navigator.pop(context);
                          }
                        },
                      );
                    },
                  ),
          ),

          // Theme Selector & Footer
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Dark Mode', style: TextStyle(fontSize: 14)),
                Switch(
                  value: isDark,
                  onChanged: (val) {
                    ref.read(themeModeProvider.notifier).state =
                        val ? ThemeMode.dark : ThemeMode.light;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- COMPONENT: Search Bar ---
  Widget _buildSearchBar(BuildContext context, WidgetRef ref) {
    final queryController = TextEditingController(text: ref.read(searchQueryProvider));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: queryController,
        onChanged: (val) {
          ref.read(searchQueryProvider.notifier).state = val;
        },
        decoration: InputDecoration(
          hintText: 'Search notes, bodies, or tags...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: queryController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    queryController.clear();
                    ref.read(searchQueryProvider.notifier).state = '';
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).cardColor.withOpacity(0.6),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // --- COMPONENT: Notes Grid ---
  Widget _buildNotesGrid(
    BuildContext context,
    WidgetRef ref,
    List<Note> notes,
    bool isMobile,
  ) {
    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No notes match selection',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Try matching another search or tag.',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      );
    }

    final activeNote = ref.watch(activeNoteProvider);

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isMobile ? 400 : 350,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.1,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final isSelected = activeNote?.id == note.id;
        final dateStr = DateFormat('MMM dd, yyyy').format(note.updatedAt);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // Fetch Background tint
        final noteColorTuple = noteColorPalette[note.color];
        final customColor = isDark ? noteColorTuple.$2 : noteColorTuple.$1;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _openNoteEditor(context, ref, note),
            child: Card(
              color: customColor == Colors.transparent
                  ? Theme.of(context).cardColor
                  : customColor.withOpacity(isDark ? 0.35 : 0.8),
              elevation: isSelected ? 4 : 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.withOpacity(0.15),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Pin indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        if (note.isPinned)
                          const Icon(Icons.push_pin, size: 14, color: Colors.amber),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Body Snippet
                    Expanded(
                      child: Text(
                        note.content ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Date & Trash
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dateStr,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        GestureDetector(
                          onTap: () {
                            ref.read(databaseProvider).deleteNote(note);
                            if (activeNote?.id == note.id) {
                              ref.read(activeNoteProvider.notifier).state = null;
                            }
                          },
                          child: const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- COMPONENT: Desktop Welcome Screen ---
  Widget _buildEmptyStateEditor(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_note, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 24),
          const Text(
            'Write Without Friction',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Select an existing note or create a new one to start writing.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _openNoteEditor(context, ref, null),
            icon: const Icon(Icons.add),
            label: const Text('Create New Note', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- LAYOUT ACTION: Open/Select Note ---
  void _openNoteEditor(BuildContext context, WidgetRef ref, Note? note) async {
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 900;

    if (note == null) {
      final db = ref.read(databaseProvider);
      final id = await db.insertNote(drift.NotesCompanion(
        title: const drift.Value('Untitled Note'),
        content: const drift.Value(''),
        createdAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      ));

      final newNote = Note(
        id: id,
        title: 'Untitled Note',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        color: 0,
        tags: null,
      );

      if (isDesktop) {
        ref.read(activeNoteProvider.notifier).state = newNote;
      } else {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditorView(note: newNote),
            ),
          );
        }
      }
    } else {
      if (isDesktop) {
        ref.read(activeNoteProvider.notifier).state = note;
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditorView(note: note),
          ),
        );
      }
    }
  }
}

// --- SUB-WIDGET: Sidebar Row ---
class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.title,
    this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.4) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? theme.colorScheme.primary : Colors.grey[600],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? theme.colorScheme.primary : null,
                  ),
                ),
              ),
              if (count != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? theme.colorScheme.primary : Colors.grey[600],
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
