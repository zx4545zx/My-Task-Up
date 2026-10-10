import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import 'list_repository.dart';

final listRepositoryProvider = Provider<ListRepository>(
  (ref) => ListRepository(ref.watch(appDatabaseProvider)),
);
