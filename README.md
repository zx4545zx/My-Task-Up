# My Task Up

My Task Up is a local-first Flutter task manager for Web, Android, macOS, and Windows. It stores tasks, lists, and settings on the device. It does not sync data between devices.

## Run the app

Install Flutter 3.44 or later, then run:

```sh
flutter pub get
dart run build_runner build
flutter run -d chrome
```

Use `flutter devices` to find a macOS, Windows, or Android target. The desktop app opens at 1280 by 800 pixels and enforces an 800 by 600 minimum size.

## Verify the app

Run the local platform gates with:

```sh
scripts/verify_flutter.sh m11
```

The script formats the project, runs analysis and tests, checks Web storage, and builds Web, Android APK, and macOS release targets. Windows release builds run in GitHub Actions. See `.audit/evidence` for platform logs and screenshots.

## Data and backups

Native builds store the database in application support storage. Web builds store it in browser storage. My Task Up has no account or cloud backup.

Settings can export a versioned JSON backup and import a backup by replacing all current tasks, lists, and settings. Import validates the complete file before it writes. Files larger than 50 MiB are rejected. Keep an extra copy of important data before importing. Delete all data requires confirmation, removes tasks and custom lists, keeps Inbox, and resets settings.

Completing a recurring task creates its next task once. Restoring and completing it again will not recreate that task if you moved, edited, completed, or deleted it.

## Notifications

Local reminders apply to tasks with a due date and time. The app asks the operating system for the permissions each platform needs. Web notifications are not supported. Windows may keep a delivered notification in its history even after the task changes; pending reminders can still be canceled without package identity.

## Desktop controls

- `Ctrl+N` or `Cmd+N` opens the new-task dialog.
- `Ctrl+K` or `Cmd+K` opens search.
- `Ctrl+Enter` or `Cmd+Enter` saves the active task edit or quick-add field.
- `Delete` asks for confirmation before deleting the selected task.
- `Esc` closes the active dialog, clears quick-add text, or clears the selected task.
- Drag the task handle to reorder tasks. Drag it to Inbox or a custom list to move the task and its subtasks.
- Drag the list handle to reorder custom lists. Use the task and list action menus for duplicate, rename, and delete commands.

The app ignores unmodified delete and escape shortcuts while a text field has focus. Modified shortcuts are app commands and remain available while entering text.

## Manual acceptance checklist

- Resize the desktop window. Confirm that it cannot shrink below 800 by 600 pixels.
- Create, edit, complete, restore, duplicate, move, reorder, and delete tasks. Confirm that Delete asks before removing a task and Ctrl+Enter or Cmd+Enter saves edits without changing completion.
- Create, rename, reorder by dragging, and delete custom lists. Confirm that Inbox cannot be deleted or renamed.
- Use each keyboard shortcut. Type ordinary letters in task, search, and notes fields to confirm that text input remains intact.
- Export a backup, import it into a test database, and confirm that tasks, lists, recurrence, and settings return. Try a malformed file and confirm that existing data stays unchanged.
- Delete all data. Confirm that the app keeps Inbox and resets settings.
- On supported native platforms, grant notification permission and test a due-time reminder. Edit, complete, restore, delete, import, and disable notifications. Confirm that the app reports pending cancellation failures.
- Add several thousand tasks. Scroll, search, reorder, and open task details. Compare the visible item count and test timing with `.audit/evidence/m11-large-list.log`.

MSIX packaging needs an approved Publisher identity before the app can ship as an installable Windows package. The current Windows CI evidence covers the release build, not MSIX installation.
