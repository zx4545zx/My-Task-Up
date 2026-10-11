import 'package:uuid/uuid.dart';

final class TaskId {
  TaskId.parse(String value) : value = _parseUuid(value);
  TaskId.newId() : value = const Uuid().v4();

  final String value;

  @override
  bool operator ==(Object other) => other is TaskId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class ListId {
  static final inbox = ListId.parse('00000000-0000-4000-8000-000000000001');

  ListId.parse(String value) : value = _parseUuid(value);
  ListId.newId() : value = const Uuid().v4();

  final String value;

  @override
  bool operator ==(Object other) => other is ListId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

String _parseUuid(String value) {
  final normalized = value.toLowerCase();
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  ).hasMatch(normalized)) {
    throw FormatException('Invalid UUID: $value');
  }
  return normalized;
}
