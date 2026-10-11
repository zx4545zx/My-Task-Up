import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/domain/ids.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [TaskLists, Tasks, ReminderRegistrations, AppSettingsEntries],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase()
    : super(
        driftDatabase(
          name: 'my_task_up',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
            onResult: (result) {
              final implementation = result.chosenImplementation;
              if (implementation == WasmStorageImplementation.unsafeIndexedDb ||
                  implementation == WasmStorageImplementation.inMemory) {
                throw StateError(
                  'This browser cannot provide safe, durable local storage.',
                );
              }
            },
          ),
        ),
      );

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      final now = DateTime.now().millisecondsSinceEpoch;
      await into(taskLists).insert(
        TaskListsCompanion.insert(
          id: ListId.inbox.value,
          name: 'Inbox',
          position: 0,
          isInbox: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await into(appSettingsEntries).insert(
        AppSettingsEntriesCompanion.insert(
          id: 'primary',
          defaultListId: ListId.inbox.value,
          notificationsEnabled: const Value(false),
        ),
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(reminderRegistrations);
        await (update(appSettingsEntries)).write(
          const AppSettingsEntriesCompanion(notificationsEnabled: Value(false)),
        );
      }
      if (from < 3) {
        await m.addColumn(tasks, tasks.recurrenceSeriesId);
      }
      if (from < 4) {
        await m.addColumn(tasks, tasks.nextOccurrenceId);
      }
    },
  );
}
