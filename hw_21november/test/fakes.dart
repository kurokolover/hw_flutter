import 'dart:async';

import 'package:todo_storage_testing_task/storage.dart';

class MemoryStore implements TextStore {
  MemoryStore([this.value]);

  String? value;
  Object? readError;
  Object? writeError;

  @override
  Future<String?> read() async {
    if (readError case final Object error) throw error;
    return value;
  }

  @override
  Future<void> write(String value) async {
    if (writeError case final Object error) throw error;
    this.value = value;
  }
}

class PendingStore extends MemoryStore {
  final pending = Completer<String?>();

  @override
  Future<String?> read() => pending.future;
}
