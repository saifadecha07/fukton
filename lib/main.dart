import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'notify.dart';
import 'path_page.dart';
import 'extras.dart';
import 'lan.dart';
import 'practice.dart';
import 'ritual.dart';
import 'store.dart';
import 'theme.dart';
import 'today.dart';
import 'verses_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  await store.load();
  try {
    await initNotifications();
  } catch (_) {}
  runApp(FuktonApp(store: store));
}

class FuktonApp extends StatelessWidget {
  final Store store;
  const FuktonApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ฝึกตน',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('th'),
        home: Home(store: store),
      );
}

class Home extends StatefulWidget {
  final Store store;
  const Home({super.key, required this.store});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int tab = 0;
  bool _onboarding = false;
  late final practice = PracticeController(widget.store);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRitual());
  }

  // Open the morning ritual on the first visit of each day.
  Future<void> _maybeRitual() async {
    final k = todayKey();
    final prefs = widget.store.prefs;
    widget.store.syncWidget();
    if (prefs.getBool('onboarded') != true) {
      if (_onboarding) return;
      _onboarding = true;
      await openOnboarding(context, widget.store);
      _onboarding = false;
      return;
    }
    if (prefs.getString('ritual-day') == k || widget.store.day(k)['intent'] != null) return;
    prefs.setString('ritual-day', k);
    openRitual(context, widget.store);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Refresh "today" when the app comes back after midnight.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      setState(() {});
      _maybeRitual();
    }
  }

  void _goPractice(String mode) {
    practice.setMode(mode);
    setState(() => tab = 1);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: widget.store,
            builder: (context, _) => IndexedStack(index: tab, children: [
              TodayPage(store: widget.store, onPractice: _goPractice, onSettings: () => openReminderSheet(context, widget.store)),
              PracticePage(c: practice),
              LanPage(store: widget.store),
              const VersesPage(),
              PathPage(store: widget.store),
            ]),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.wb_twilight_rounded), label: 'วันนี้'),
            NavigationDestination(icon: Icon(Icons.self_improvement_rounded), label: 'ฝึก'),
            NavigationDestination(icon: Icon(Icons.sports_esports_outlined), label: 'ลาน'),
            NavigationDestination(icon: Icon(Icons.auto_stories_outlined), label: 'คาถา'),
            NavigationDestination(icon: Icon(Icons.timeline_rounded), label: 'เส้นทาง'),
          ],
        ),
      ),
    );
  }
}
