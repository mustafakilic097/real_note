import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:real_note/core/viewmodel/notes_notifier.dart';

import '../core/model/note_local.dart';

final _queryProvider = StateProvider.autoDispose<String>((_) => '');

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});
  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _createNote() async {
    final res = await showModalBottomSheet<_NoteFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _NoteFormSheet(),
    );
    if (res != null && res.title.trim().isNotEmpty) {
      await ref.read(notesListControllerProvider.notifier).createNote(res.title.trim(), content: res.content.trim());
    }
  }

  Future<void> _editNote(NoteLocal note) async {
    final res = await showModalBottomSheet<_NoteFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _NoteFormSheet(initialTitle: note.title, initialContent: note.content),
    );
    if (res != null) {
      await ref
          .read(notesListControllerProvider.notifier)
          .updateNote(note, title: res.title.trim(), content: res.content.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesListControllerProvider);
    final query = ref.watch(_queryProvider);

    return Scaffold(
      drawer: const _AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNote,
        icon: const Icon(Icons.add),
        label: const Text('Yeni not'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: RefreshIndicator.adaptive(
        onRefresh: () => ref.read(notesListControllerProvider.notifier).refreshSync(),
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              leading: Builder(
                builder: (ctx) => IconButton(
                  tooltip: 'Menü',
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              title: const Text('Notlar'),
              actions: [
                IconButton(
                  tooltip: 'Senkronize et',
                  onPressed: () => ref.read(notesListControllerProvider.notifier).refreshSync(),
                  icon: const Icon(Icons.sync),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(72),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SearchBar(
                    controller: _search,
                    leading: const Icon(Icons.search),
                    hintText: 'Notlarda ara…',
                    onChanged: (v) => ref.read(_queryProvider.notifier).state = v,
                    trailing: [
                      if (query.isNotEmpty)
                        IconButton(
                          tooltip: 'Temizle',
                          onPressed: () {
                            _search.clear();
                            ref.read(_queryProvider.notifier).state = '';
                          },
                          icon: const Icon(Icons.clear),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              sliver: notes.when<Widget>(
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(padding: EdgeInsets.only(top: 48), child: CircularProgressIndicator()),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(padding: const EdgeInsets.all(16), child: Text('Hata: $e')),
                ),
                data: (items) {
                  final q = query.toLowerCase();
                  final filtered = q.isEmpty
                      ? items
                      : items
                            .where((n) => n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q))
                            .toList();

                  if (filtered.isEmpty) {
                    return const SliverToBoxAdapter(child: _EmptyState());
                  }

                  return SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _NoteCard(
                      note: filtered[i],
                      onEdit: () => _editNote(filtered[i]),
                      onDelete: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Silinsin mi?'),
                            content: const Text('Bu notu silmek istediğine emin misin?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await ref.read(notesListControllerProvider.notifier).deleteNote(filtered[i]);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onEdit, required this.onDelete});
  final NoteLocal note;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final dirty = note.isDirty || note.isDeletedLocally;
    final date = DateFormat('d MMM y • HH:mm').format(note.updatedAt.toLocal());
    final outline = Theme.of(context).colorScheme.outline;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  shape: const CircleBorder(),
                  color: Theme.of(context).colorScheme.secondaryContainer,
                ),
                child: const Icon(Icons.description_outlined, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (dirty)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Badge(label: Text('offline')),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: outline),
                        const SizedBox(width: 6),
                        Text(date, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: outline)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    final name = u?.displayName ?? (u?.email?.split('@').first ?? 'Kullanıcı');
    final email = u?.email ?? '—';

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              leading: CircleAvatar(
                radius: 22,
                foregroundImage: (u?.photoURL != null) ? NetworkImage(u!.photoURL!) : null,
                child: (u?.photoURL == null) ? const Icon(Icons.person) : null,
              ),
              title: Text(name),
              subtitle: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Profilim'),
              onTap: () async {
                Navigator.pop(context);
                await showModalBottomSheet(
                  context: context,
                  useSafeArea: true,
                  showDragHandle: true,
                  builder: (_) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Profil', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              foregroundImage: (u?.photoURL != null) ? NetworkImage(u!.photoURL!) : null,
                              child: (u?.photoURL == null) ? const Icon(Icons.person, size: 28) : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 4),
                                  Text(email),
                                  const SizedBox(height: 4),
                                  Text(
                                    'UID: ${u?.uid ?? "—"}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.check),
                            label: const Text('Tamam'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Ayarlar'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ayarlar yakında')));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Çıkış yap'),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteFormSheet extends StatefulWidget {
  const _NoteFormSheet({this.initialTitle, this.initialContent});
  final String? initialTitle;
  final String? initialContent;

  @override
  State<_NoteFormSheet> createState() => _NoteFormSheetState();
}

class _NoteFormSheetState extends State<_NoteFormSheet> {
  late final TextEditingController _title = TextEditingController(text: widget.initialTitle ?? '');
  late final TextEditingController _content = TextEditingController(text: widget.initialContent ?? '');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 24),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              widget.initialTitle == null ? 'Yeni not' : 'Notu düzenle',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Başlık', prefixIcon: Icon(Icons.title), filled: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Başlık zorunlu' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _content,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'İçerik',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Vazgeç'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.pop(context, _NoteFormResult(_title.text, _content.text));
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Kaydet'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteFormResult {
  const _NoteFormResult(this.title, this.content);
  final String title;
  final String content;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.note_alt_outlined, size: 72),
          const SizedBox(height: 12),
          Text('Henüz not yok', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Sağ alttan yeni bir not oluşturabilir veya arama yapabilirsin.', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
