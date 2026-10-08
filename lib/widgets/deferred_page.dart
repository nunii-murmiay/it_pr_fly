import 'package:flutter/material.dart';

typedef LibraryLoader = Future<void> Function();

/// Подгружает редко открываемый раздел после старта приложения.
class DeferredPage extends StatefulWidget {
  final LibraryLoader loadLibrary;
  final WidgetBuilder builder;

  const DeferredPage({
    super.key,
    required this.loadLibrary,
    required this.builder,
  });

  @override
  State<DeferredPage> createState() => _DeferredPageState();
}

class _DeferredPageState extends State<DeferredPage> {
  late final Future<void> _ready = widget.loadLibrary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Открываем раздел…'),
                ],
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Не удалось загрузить раздел. Обновите страницу.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return widget.builder(context);
      },
    );
  }
}
