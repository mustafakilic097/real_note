import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:real_note/core/init/network/network_manager.dart';

class NotesApi {
  NotesApi(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> fetchNotes() async {
    final res = await _dio.get('/notes');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createNote(Map<String, dynamic> body) async {
    final res = await _dio.post('/notes', data: body);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateNote(String id, Map<String, dynamic> body) async {
    final res = await _dio.put('/notes/$id', data: body);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteNote(String id) async {
    await _dio.delete('/notes/$id');
  }
}

final notesApiProvider = Provider<NotesApi>((ref) {
  final dio = ref.watch(NetworkManager.instance.dioProvider);
  return NotesApi(dio);
});
