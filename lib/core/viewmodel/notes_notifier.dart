import 'dart:async' show unawaited;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../init/network/network_manager.dart';
import '../model/note_local.dart';
import 'notes_viewmodel.dart';

final notesListControllerProvider = AsyncNotifierProvider<NotesListController, List<NoteLocal>>(
  NotesListController.new,
);
final authChangesProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.userChanges());

class NotesListController extends AsyncNotifier<List<NoteLocal>> {
  @override
  Future<List<NoteLocal>> build() async {
    await ref.read(isarProvider.future);

    ref.listen<AsyncValue<User?>>(authChangesProvider, (prev, next) {
      final prevUid = prev?.value?.uid;
      final nextUid = next.value?.uid;
      if (prevUid != nextUid) {
        Future.microtask(() async {
          await ref.read(notesRepositoryProvider).purgeOtherUsers();
          await refreshSync();
        });
      }
    });

    final repo = ref.read(notesRepositoryProvider);

    try {
      final conn = await Connectivity().checkConnectivity();
      if (conn != ConnectivityResult.none) {
        await repo.push();
        await repo.pull();
      }
    } catch (_) {}

    return repo.loadLocal();
  }

  Future<void> refreshSync() async {
    final repo = ref.read(notesRepositoryProvider);
    try {
      await repo.push();
      await repo.pull();
    } finally {
      state = AsyncData(await repo.loadLocal());
    }
  }

  Future<void> createNote(String title, {String content = ""}) async {
    final repo = ref.read(notesRepositoryProvider);
    await repo.createLocal(title: title, content: content);
    state = AsyncData(await repo.loadLocal());
    unawaited(repo.push());
  }

  Future<void> updateNote(NoteLocal note, {String? title, String? content}) async {
    final repo = ref.read(notesRepositoryProvider);
    await repo.updateLocal(note, title: title, content: content);
    state = AsyncData(await repo.loadLocal());
    unawaited(repo.push());
  }

  Future<void> deleteNote(NoteLocal note) async {
    final repo = ref.read(notesRepositoryProvider);
    await repo.deleteLocal(note);
    state = AsyncData(await repo.loadLocal());
    unawaited(repo.push());
  }
}
