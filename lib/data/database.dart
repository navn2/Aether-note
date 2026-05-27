import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// The generator will create this file later.
// Ignore the red error line on this for now.
part 'database.g.dart';

// 1. Define the 'Notes' table
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 100)();
  TextColumn get content => text().named('body').nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get color => integer().withDefault(const Constant(0))();
  TextColumn get tags => text().nullable()();
}

// 2. The Database Class
@DriftDatabase(tables: [Notes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // --- ACTIONS ---

  // Get all notes (Pinned first, then newest updated first)
  Stream<List<Note>> watchAllNotes() =>
      (select(notes)
            ..orderBy([
              (t) => OrderingTerm.desc(t.isPinned),
              (t) => OrderingTerm.desc(t.updatedAt),
            ]))
          .watch();

  // Insert a note
  Future<int> insertNote(NotesCompanion note) => into(notes).insert(note);

  // Update a note
  Future<bool> updateNote(Note note) => update(notes).replace(note);

  // Delete a note
  Future<int> deleteNote(Note note) => delete(notes).delete(note);
}

// 3. Open the file on Windows
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'my_notes.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
