import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preferences_store.dart';
import 'storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = TodoRepository(PreferencesStore(SharedPreferencesAsync()));
  runApp(TodoApp(repository: repository));
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key, required this.repository});

  final TodoRepository repository;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: TodoPage(repository: repository),
  );
}

class TodoPage extends StatefulWidget {
  const TodoPage({super.key, required this.repository});

  final TodoRepository repository;

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  List<Todo> items = [];
  bool loading = true;
  bool saving = false;
  String? error;

  bool get busy => loading || saving || error != null;

  @override
  void initState() {
    super.initState();
    loadTodos();
  }

  Future<void> loadTodos() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        items = loaded;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Не удалось прочитать задачи';
        loading = false;
      });
    }
  }

  Future<void> persistNext(List<Todo> next) async {
    if (busy) return;
    setState(() => saving = true);
    try {
      await widget.repository.save(next);
      if (!mounted) return;
      setState(() => items = next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не удалось сохранить')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> openAddPage() async {
    final title = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const AddTodoPage()));
    if (!mounted || title == null) return;

    final lastId = items.fold(0, (max, todo) => todo.id > max ? todo.id : max);
    await persistNext([...items, Todo(lastId + 1, title)]);
  }

  Future<void> deleteTodo(Todo todo) async {
    final confirmed = await confirmDelete(context, todo);
    if (!mounted || confirmed != true) return;

    await persistNext(items.where((item) => item.id != todo.id).toList());
  }

  Widget readError(String message) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        TextButton(
          key: const Key('retry_button'),
          onPressed: loadTodos,
          child: const Text('Повторить'),
        ),
      ],
    ),
  );

  Widget todoList() => ListView(
    padding: const EdgeInsets.only(bottom: 88),
    children: [
      for (final todo in items)
        ListTile(
          key: ValueKey(todo.id),
          title: Text(todo.title),
          trailing: IconButton(
            tooltip: 'Удалить',
            onPressed: busy ? null : () => deleteTodo(todo),
            icon: const Icon(Icons.delete_outline),
          ),
        ),
    ],
  );

  Widget body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error case final String message) return readError(message);
    if (items.isEmpty) return const Center(child: Text('Пока нет задач'));
    return todoList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Задачи')),
    body: body(),
    floatingActionButton: FloatingActionButton(
      key: const Key('add_todo_button'),
      tooltip: 'Добавить',
      onPressed: busy ? null : openAddPage,
      child: const Icon(Icons.add),
    ),
  );
}

Future<bool?> confirmDelete(BuildContext context, Todo todo) =>
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить задачу?'),
        content: Text(todo.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

class AddTodoPage extends StatefulWidget {
  const AddTodoPage({super.key});

  @override
  State<AddTodoPage> createState() => _AddTodoPageState();
}

class _AddTodoPageState extends State<AddTodoPage> {
  final controller = TextEditingController();
  String? errorText;

  void save() {
    final title = controller.text.trim();
    if (title.isEmpty) {
      setState(() => errorText = 'Введите название');
      return;
    }
    Navigator.of(context).pop(title);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Новая задача')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          key: const Key('todo_title_field'),
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Название',
            errorText: errorText,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('save_todo_button'),
          onPressed: save,
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}
