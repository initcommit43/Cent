import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/transactions_repository.dart';

final entryProvider = StreamProvider.autoDispose.family<EntryView?, int>(
  (ref, id) => ref.watch(transactionsRepositoryProvider).watchOne(id),
);
