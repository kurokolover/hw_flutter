import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import 'cat_api.dart';

void main() => runApp(CatApp(api: CatApi(http.Client())));

const ink = Color(0xff293d36);
const paper = Color(0xfffffaf2);
const coral = Color(0xffa73f31);

class CatApp extends StatelessWidget {
  const CatApp({super.key, required this.api});
  final CatApi api;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Кототиндер',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        primary: ink,
        surface: paper,
      ),
      scaffoldBackgroundColor: paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: paper,
        indicatorColor: Color(0xffd7e7d6),
      ),
    ),
    home: Home(api: api),
  );
}

Widget mark(String id, Widget child) =>
    Semantics(identifier: id, key: ValueKey(id), child: child);

class Home extends StatefulWidget {
  const Home({super.key, required this.api});
  final CatApi api;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0, likes = 0;
  bool loading = false, loadingBreeds = false;
  String? error, breedError;
  Cat? cat;
  List<Breed>? breeds;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool liked = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
      if (liked) likes++;
    });
    try {
      final next = await widget.api.next();
      if (mounted) {
        setState(() {
          cat = next;
          loading = false;
        });
      }
    } on LoadFailure catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          loading = false;
        });
      }
    }
  }

  Future<void> catalog() async {
    if (loadingBreeds || breeds != null) return;
    setState(() {
      loadingBreeds = true;
      breedError = null;
    });
    try {
      final result = await widget.api.breeds();
      if (mounted) {
        setState(() {
          breeds = result;
          loadingBreeds = false;
        });
      }
    } on LoadFailure catch (e) {
      if (mounted) {
        setState(() {
          breedError = e.message;
          loadingBreeds = false;
        });
      }
    }
  }

  void open(Breed breed, [Uri? photo]) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BreedDetails(breed: breed, photo: photo),
      ),
    );
  }

  Widget feed() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Retry(message: error!, retry: load);
    final current = cat;
    if (current == null) return const SizedBox.shrink();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              mark(
                'cat_card',
                Dismissible(
                  key: ObjectKey(current),
                  direction: DismissDirection.horizontal,
                  confirmDismiss: (direction) async {
                    load(liked: direction == DismissDirection.startToEnd);
                    return false;
                  },
                  background: const ColoredBox(color: Color(0xffd7e7d6)),
                  secondaryBackground: const ColoredBox(
                    color: Color(0xffeed6ca),
                  ),
                  child: Material(
                    clipBehavior: Clip.antiAlias,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: () => open(current.breed, current.photo),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CatPhoto(url: current.photo),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Expanded(
                                  child: mark(
                                    'cat_breed_name',
                                    Text(
                                      current.breed.name,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        color: ink,
                                      ),
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  mark(
                    'dislike_button',
                    OutlinedButton.icon(
                      onPressed: () => load(),
                      icon: const Icon(Icons.close),
                      label: const Text('Пропуск'),
                    ),
                  ),
                  mark(
                    'like_button',
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: coral),
                      onPressed: () => load(liked: true),
                      icon: const Icon(Icons.favorite),
                      label: const Text('Лайк'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget catalogView() {
    if (breedError != null) return Retry(message: breedError!, retry: catalog);
    final items = breeds;
    if (items == null) return const Center(child: CircularProgressIndicator());
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        title: Text(items[i].name),
        subtitle: items[i].facts['Страна'] == null
            ? null
            : Text(items[i].facts['Страна']!),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => open(items[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        tab == 0 ? 'Кототиндер' : 'Породы',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        if (tab == 0)
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: mark(
              'like_counter',
              Row(
                children: [
                  const Icon(Icons.favorite, color: coral, size: 19),
                  const SizedBox(width: 5),
                  Text('$likes'),
                ],
              ),
            ),
          ),
      ],
    ),
    body: tab == 0 ? feed() : catalogView(),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (value) {
        setState(() => tab = value);
        if (value == 1) catalog();
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.pets_outlined),
          label: 'Коты',
        ),
        mark(
          'breeds_tab',
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Породы',
          ),
        ),
      ],
    ),
  );
}

class Retry extends StatelessWidget {
  const Retry({super.key, required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 32, color: ink),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          mark(
            'retry_button',
            OutlinedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ),
        ],
      ),
    ),
  );
}

class CatPhoto extends StatefulWidget {
  const CatPhoto({super.key, required this.url});
  final Uri url;
  @override
  State<CatPhoto> createState() => _CatPhotoState();
}

class _CatPhotoState extends State<CatPhoto> {
  int attempt = 0;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.12,
    child: Image.network(
      widget.url.toString(),
      key: ValueKey(attempt),
      fit: BoxFit.cover,
      semanticLabel: 'Фотография кота',
      frameBuilder: (_, child, frame, sync) => frame != null || sync
          ? child
          : const Center(child: CircularProgressIndicator()),
      errorBuilder: (_, _, _) => Retry(
        message: 'Не удалось загрузить фото.',
        retry: () {
          setState(() => attempt++);
        },
      ),
    ),
  );
}

class BreedDetails extends StatelessWidget {
  const BreedDetails({super.key, required this.breed, this.photo});
  final Breed breed;
  final Uri? photo;
  @override
  Widget build(BuildContext context) {
    final facts = photo == null
        ? breed.facts.entries.take(4)
        : breed.facts.entries;
    return Scaffold(
      appBar: AppBar(title: const Text('О породе')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            if (photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CatPhoto(url: photo!),
              ),
            const SizedBox(height: 16),
            Text(
              breed.name,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              breed.description.isEmpty
                  ? 'Описание отсутствует.'
                  : breed.description,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 16),
            for (final fact in facts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(fact.key),
                subtitle: Text(fact.value),
                shape: const Border(top: BorderSide(color: Color(0xffdeded3))),
              ),
          ],
        ),
      ),
    );
  }
}
