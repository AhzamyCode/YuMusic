import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../providers.dart';
import 'widgets/home_widgets.dart';
import 'widgets/track_tile.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) => setState(() => _query = value.trim());

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: SearchBar(
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
              controller: _controller,
              hintText: s.searchHint,
              leading: const Icon(Icons.search),
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              trailing: [
                if (_query.isNotEmpty || _controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      _submit('');
                    },
                  ),
              ],
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(child: _query.isEmpty ? _home(s) : _results(s)),
        ],
      ),
    );
  }

  Widget _home(S s) => ListView(
        children: [
          SectionHeader(s.browse),
          const GenreGrid(),
          const SizedBox(height: 24),
        ],
      );

  Widget _results(S s) {
    final results = ref.watch(searchProvider(_query));
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _Message(
        icon: Icons.cloud_off,
        text: s.searchFailed,
        action: FilledButton.tonal(
          onPressed: () => ref.invalidate(searchProvider(_query)),
          child: Text(s.retry),
        ),
      ),
      data: (results) {
        if (results.isEmpty) {
          return _Message(icon: Icons.search_off, text: s.noResults);
        }
        final songs = results.songs;
        final handler = ref.read(audioHandlerProvider);
        return ListView(
          children: [
            if (results.albums.isNotEmpty) ...[
              SectionHeader(s.albums),
              CardRow(
                children: [
                  for (final album in results.albums) AlbumCard(album),
                ],
              ),
            ],
            if (songs.isNotEmpty) ...[
              SectionHeader(s.songsTitle),
              for (final track in songs)
                TrackTile(
                  track: track,
                  // Yang berikutnya diputar adalah lagu yang mirip, bukan
                  // hasil pencarian di bawahnya.
                  onTap: () => handler.playWithRadio(track),
                ),
            ],
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
