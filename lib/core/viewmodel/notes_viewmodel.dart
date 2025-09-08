import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../init/network/network_manager.dart';
import '../model/note_local.dart';
import 'notes_db.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final api = ref.watch(notesApiProvider);
  return NotesRepository(ref, api);
});

class NotesRepository {
  NotesRepository(this._ref, this._api);
  final Ref _ref;
  final NotesApi _api;
  final _uuid = const Uuid();

  Future<Isar> get _isar async => _ref.read(isarProvider.future);
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<List<NoteLocal>> loadLocal() async {
    final isar = await _isar;
    return isar.noteLocals.filter().userIdEqualTo(_uid).isDeletedLocallyEqualTo(false).sortByUpdatedAtDesc().findAll();
  }

  Future<NoteLocal> createLocal({required String title, String content = ""}) async {
    final isar = await _isar;
    final n = NoteLocal()
      ..id = _uuid.v4()
      ..userId = _uid
      ..title = title
      ..content = content
      ..createdAt = DateTime.now().toUtc()
      ..updatedAt = DateTime.now().toUtc()
      ..isDirty = true
      ..isDeletedLocally = false;
    await isar.writeTxn(() => isar.noteLocals.put(n));
    return n;
  }

  Future<void> updateLocal(NoteLocal n, {String? title, String? content}) async {
    final isar = await _isar;
    n.title = title ?? n.title;
    n.content = content ?? n.content;
    n.updatedAt = DateTime.now().toUtc();
    n.isDirty = true;
    await isar.writeTxn(() => isar.noteLocals.put(n));
  }

  Future<void> deleteLocal(NoteLocal n) async {
    final isar = await _isar;
    n.isDeletedLocally = true;
    n.isDirty = true;
    n.updatedAt = DateTime.now().toUtc();
    await isar.writeTxn(() => isar.noteLocals.put(n));
  }

  Future<void> pull() async {
    final isar = await _isar;
    final remote = await _api.fetchNotes();
    final uid = _uid;

    await isar.writeTxn(() async {
      for (final r in remote) {
        if (r['userId'] != uid) continue;
        final id = r['id'] as String;
        final local = await isar.noteLocals.where().idEqualTo(id).findFirst();
        final rUpdated = DateTime.parse(r['updatedAt']).toUtc();

        if (local == null) {
          final n = NoteLocal()
            ..id = id
            ..userId = r['userId']
            ..title = r['title'] ?? ''
            ..content = r['content'] ?? ''
            ..createdAt = DateTime.parse(r['createdAt']).toUtc()
            ..updatedAt = rUpdated
            ..isDirty = false
            ..isDeletedLocally = false;
          await isar.noteLocals.put(n);
        } else {
          if (rUpdated.isAfter(local.updatedAt)) {
            local
              ..title = r['title'] ?? ''
              ..content = r['content'] ?? ''
              ..updatedAt = rUpdated
              ..isDirty = false
              ..isDeletedLocally = false;
            await isar.noteLocals.put(local);
          }
        }
      }
    });
  }

  Future<void> push() async {
    final isar = await _isar;
    final uid = _uid;
    final dirty = await isar.noteLocals.filter().userIdEqualTo(uid).isDirtyEqualTo(true).findAll();

    for (final n in dirty) {
      if (n.isDeletedLocally) {
        await _api.deleteNote(n.id);
        await isar.writeTxn(() => isar.noteLocals.delete(n.isarId));
      } else {
        try {
          await _api.createNote({"id": n.id, "title": n.title, "content": n.content});
        } catch (_) {
          await _api.updateNote(n.id, {"title": n.title, "content": n.content});
        }
        n.isDirty = false;
        await isar.writeTxn(() => isar.noteLocals.put(n));
      }
    }
  }

  Future<void> purgeOtherUsers() async {
    final isar = await _isar;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await isar.writeTxn(() async {
      if (uid == null) {
        await isar.noteLocals.clear();
      } else {
        await isar.noteLocals.filter().not().userIdEqualTo(uid).deleteAll();
      }
    });
  }
}
