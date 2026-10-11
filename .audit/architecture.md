# Architecture for My Task Up

## Problem

My Task Up starts from a Flutter counter scaffold. The approved app needs durable local data, list and task workflows, recurrence, local reminders, and complete JSON replacement across Web and native targets. UI code must not depend on Drift. The design must keep each invariant in one owner and fit the M0–M11 sequence.

## Caller usage

Screens watch typed Riverpod query providers and send one typed user intent. They do not build SQL or coordinate reminders.

```dart
final tasks = ref.watch(taskFeedProvider(const TaskFeed.inbox()));
await ref.read(taskCommandsProvider).create(
  TaskDraft(title: TaskTitle.parse(input), listId: selectedListId),
);
await ref.read(taskCommandsProvider).complete(task.id);
await ref.read(backupCommandsProvider).importJson(untrustedJson);
```

Task, list, settings, and backup features own their query providers and command entry points. A task completion command owns recurrence and reminder consequences. Import owns parsing, validation, database replacement, and post-commit reminder reconciliation.

## Chosen shape

Candidate 1 is the base. It keeps Drift tables private, gives each feature its own typed repository and Riverpod providers, and uses database queries for Inbox, Today, Upcoming, completed, and search feeds. It avoids a shared CRUD abstraction and does not expose database handles to widgets.

Candidate 2 contributes a stronger caller rule. Each user mutation is one typed intent. The caller does not coordinate repository writes or notification calls. The chosen design keeps this rule without collecting task, list, settings, backup, and delete-all methods in one growing service.

The core task shape is:

```dart
final class Task {
  final TaskId id;
  final ListId listId;
  final TaskId? parentId;
  final TaskTitle title;
  final String? notes;
  final LocalDue? due;
  final RepeatRule repeat;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
}
```

`TaskId`, `ListId`, and `TaskTitle` parse and validate untrusted values at their constructors. A null `completedAt` means active; a value means complete. This avoids storing two completion flags. `LocalDue` stores a local calendar date and an optional wall-clock time, so date-only tasks do not become timezone-shifting instants. `RepeatRule` is a sealed union for Never, Daily, weekdays, Weekly, Monthly, Yearly, and custom intervals. Pure recurrence functions calculate the next due value.

Drift stores primary entities in `task_lists`, `tasks`, and `app_settings`. Tasks store `list_id`, nullable `parent_id`, due day, optional due minute, repeat-rule data, timestamps, and position. Explicit indexes support list/parent order, due-date views, and completion. Position is scoped to its list and parent group, not global. The database layer enforces foreign keys and unique occurrence identity where needed. Repositories validate rules SQLite cannot express, including one-level subtasks, parent/list consistency, protected Inbox, and default-list references.

Each feature owns its repository contract and concrete Drift adapter. Task, list, and settings commands own their mutations. A backup module owns the versioned JSON codec and import validation. The UI imports only feature providers and domain types. Database rows, generated Drift classes, JSON wire types, and notification plugin types stay private.

Each command validates input, commits all related database changes in one transaction, then reconciles external reminder state. The transaction makes task completion and its single next occurrence atomic. A second completion call sees `completedAt` and does not insert another occurrence. A persisted recurrence occurrence key can provide an additional uniqueness guard if tests or database concurrency show the completion check is insufficient.

A durable reminder registry tracks the plugin identifier separately from task UUIDs. Registry rows survive task deletion until cancellation succeeds. Reconciliation compares committed tasks and settings with registry entries, creates or updates required reminders, and cancels stale entries. Startup reconciliation repairs a crash between database commit and plugin calls. Import and delete-all use the same process. Platform adapters report unsupported capability rather than substituting in-memory or unverified behavior.

Import parses the full file into private typed values, validates IDs, references, recurrence, and subtask depth, then replaces lists, tasks, and settings in one transaction. Failed validation or a failed transaction leaves the old database untouched. Reminder reconciliation runs after a successful commit.

## Module map

```text
lib/
  app/                         router, shell, provider composition
  core/
    database/                  Drift schema, migrations, native and Web connections
    domain/                    shared IDs, local calendar values, clock
  shared/                      Material theme and reusable controls
  features/
    tasks/                     task model, repository, commands, queries, UI
    lists/                     list model, repository, commands, UI
    settings/                  settings model, repository, commands, UI
    backup/                    private JSON codec, validator, replace operation
    reminders/                 capability adapter and durable reconciliation
```

A feature owns its task, list, or settings behavior. `core/database` owns storage mechanics only. `app` composes the features and does not own business rules. Keep folders flat until they contain multiple real files; do not create empty architecture layers.

## Candidate comparison

The arena candidates scored as follows. A higher number means stronger evidence in the candidate, not verified implementation.

| Criterion | Candidate 1 | Candidate 2 |
| --- | ---: | ---: |
| One intent per caller | 4 | 5 |
| Typed invariants and boundary validation | 4 | 4 |
| Atomic and idempotent lifecycle | 3 | 4 |
| Truthful Web/native boundaries | 4 | 4 |
| Interface depth without extra layers | 4 | 3 |
| M0–M11 and several-thousand-task fit | 4 | 3 |

The judge preferred candidate 1 for feature ownership and database-side feed queries. It grafted candidate 2's one-intent caller contract, explicit reminder warnings, and complete-set reorder validation. It rejected a global `TaskActions` facade, full-table feeds, and a generic transaction runner unless Drift requires one. It flagged reminder recovery after deletion and import as a required design detail.

## Tradeoffs and open verification

The feature-owned API creates some row-to-domain mapping code. That cost keeps generated schema details out of UI and lets each feature own its lifecycle. Database-side query methods add repository work, but the approved several-thousand-task requirement makes an unconditional fetch-all design a poor default.

M2 must verify durable Drift-compatible Web storage and multi-table transaction rollback before product data depends on it. M7 must prove recurrence boundary behavior against the approved specification. M8 must verify each platform's scheduling, permission, and cancellation support. In particular, the reminder registry must preserve pending cancellations across process death. M11 must measure large-list behavior before claiming performance.

The configured design and judge aliases could not authenticate in this Pi session. Two independent sketches and the cross-judge ran on the available OpenAI Codex model, `gpt-6-luna`. The resulting comparison is not a cross-family review.

## First implementation step

M1 replaces the starter counter with the responsive Material 3 shell, route table, navigation, and theme selection. M2 then implements the selected typed models, Drift schema, native and Web storage adapters, and repository tests before any task feature UI. M9 persists theme selection with the rest of the settings.
