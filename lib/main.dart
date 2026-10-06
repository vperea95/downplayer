import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/accounts_service.dart';
import 'services/download_manager.dart';
import 'services/engine.dart';
import 'services/history_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final engine = Engine();
  final history = HistoryService();
  final accounts = AccountsService(engine);
  await Future.wait([history.load(), accounts.load()]);
  final manager = DownloadManager(engine: engine, history: history, accounts: accounts);

  runApp(DownPlayerApp(engine: engine, manager: manager, history: history, accounts: accounts));

  // La primera vez descomprime Python y ffmpeg; la app se muestra mientras tanto.
  engine.init();
}

class DownPlayerApp extends StatelessWidget {
  const DownPlayerApp({
    super.key,
    required this.engine,
    required this.manager,
    required this.history,
    required this.accounts,
  });

  final Engine engine;
  final DownloadManager manager;
  final HistoryService history;
  final AccountsService accounts;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DownPlayer',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: HomeScreen(engine: engine, manager: manager, history: history, accounts: accounts),
    );
  }
}
