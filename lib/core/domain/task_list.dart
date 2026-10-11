import 'ids.dart';

final class TaskList {
  TaskList({
    required this.id,
    required String name,
    required this.position,
    required this.isInbox,
    required this.createdAt,
    required this.updatedAt,
  }) : name = name.trim() {
    if (this.name.isEmpty) throw ArgumentError.value(name, 'name');
    if (position < 0) throw ArgumentError.value(position, 'position');
  }

  final ListId id;
  final String name;
  final int position;
  final bool isInbox;
  final DateTime createdAt;
  final DateTime updatedAt;
}
