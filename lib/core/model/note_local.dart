import 'package:isar/isar.dart';
part 'note_local.g.dart';

@collection
class NoteLocal {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  @Index() // kullanıcıya göre hızlı filtre
  late String userId;

  late String title;
  String content = "";

  @Index() // updatedAt'e göre sıralama performansı
  late DateTime createdAt;

  @Index()
  late DateTime updatedAt;

  bool isDirty = false;
  bool isDeletedLocally = false;
}
