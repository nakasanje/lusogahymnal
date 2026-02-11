// main.dart
//single dovc
import 'dart:convert';
import 'package:flutter/material.dart';
//import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
// ignore: unnecessary_import
import 'dart:ui';

// ignore: depend_on_referenced_packages
import 'package:share_plus/share_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Start UI immediately (no splash / no loading screen)
  runApp(const SdaLusogaHymnalApp());

  // Load saved prefs after UI starts (non-blocking)
  settings.loadFromPrefs();
  favorites.loadFromPrefs();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<Song>> _songsFuture = loadSongs();
  final TextEditingController _jumpCtrl = TextEditingController();

  // Optional premium: “Continue reading”
  int? _lastOpened;

  @override
  void initState() {
    super.initState();
    _loadLastOpened();
  }

  Future<void> _loadLastOpened() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _lastOpened = prefs.getInt('lastOpenedSong'));
  }

  Future<void> _saveLastOpened(int n) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastOpenedSong', n);
    _lastOpened = n;
  }

  @override
  void dispose() {
    _jumpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<Song>>(
      future: _songsFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (snap.hasError) {
          return Scaffold(
            appBar: _premiumAppBar(context, title: 'SDA Lusoga Hymnal'),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Failed to load hymns:\n${snap.error}'),
            ),
          );
        }

        final songs = (snap.data ?? [])
          ..sort((a, b) => a.number.compareTo(b.number));

        Song? lastSong;
        if (_lastOpened != null) {
          final idx = songs.indexWhere((s) => s.number == _lastOpened);
          if (idx != -1) lastSong = songs[idx];
        }

        return Scaffold(
          appBar: _premiumAppBar(context, title: 'SDA Lusoga Hymnal'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              Text(
                'Jump to hymn number',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),

              // ✅ Premium input row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _jumpCtrl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.go,
                      decoration: InputDecoration(
                        hintText: 'e.g. 73',
                        prefixIcon: const Icon(Icons.numbers),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          // ignore: deprecated_member_use
                          borderSide: BorderSide(
                              color: scheme.outlineVariant
                                  .withValues(alpha: 0.25)),
                        ),
                      ),
                      onSubmitted: (_) => _openFromNumber(context, songs),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => _openFromNumber(context, songs),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Open'),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ✅ Quick Actions (premium)
              _sectionHeader(context, 'Quick actions'),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.play_circle_outline,
                          color: scheme.primary),
                      title: const Text('Continue reading'),
                      subtitle: Text(lastSong == null
                          ? 'Open any hymn to enable this.'
                          : '#${lastSong.number} — ${lastSong.title}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: lastSong == null
                          ? null
                          : () => _openSong(context, songs, lastSong!.number),
                    ),
                    Divider(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                    ListTile(
                      leading:
                          Icon(Icons.shuffle_rounded, color: scheme.primary),
                      title: const Text('Random hymn'),
                      subtitle: const Text('Surprise me'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        if (songs.isEmpty) return;
                        final picked = (songs.toList()..shuffle()).first;
                        _openSong(context, songs, picked.number);
                      },
                    ),
                    Divider(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.35)),
                    ListTile(
                      leading: Icon(Icons.star_outline, color: scheme.primary),
                      title: const Text('Open favorites'),
                      subtitle: const Text('Your saved hymns'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // Switch to Favorites tab (index = 2)
                        final appShell =
                            context.findAncestorStateOfType<_AppShellState>();
                        appShell?.setState(() => appShell.index = 2);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ✅ Small, classy info (no heavy boxes)
              _sectionHeader(context, 'Tips'),
              const SizedBox(height: 8),
              Text(
                '• Enter a number and tap Open.\n'
                '• Use Songs to search by title.\n'
                '• Tap ⭐ inside a hymn to save it.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.75),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _premiumAppBar(BuildContext context,
      {required String title}) {
    final scheme = Theme.of(context).colorScheme;

    return AppBar(
      centerTitle: false,
      elevation: 0,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.2),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
            height: 1, color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
    );
  }

  void _openFromNumber(BuildContext context, List<Song> songs) {
    final n = int.tryParse(_jumpCtrl.text.trim());
    if (n == null) return;

    _openSong(context, songs, n);
  }

  Future<void> _openSong(
      BuildContext context, List<Song> songs, int number) async {
    final idx = songs.indexWhere((s) => s.number == number);

    if (idx == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hymn #$number not found yet')),
      );
      return;
    }

    await _saveLastOpened(number);

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SongDetails(
          song: songs[idx],
          allSongs: songs,
          index: idx,
        ),
      ),
    );
  }
}

/// ----------------------
/// APP SETTINGS (global + persisted)
/// ----------------------
class AppSettings extends ChangeNotifier {
  static const _kFontSize = 'fontSize';
  static const _kLineHeight = 'lineHeight';
  static const _kThemeMode = 'themeMode'; // 0 system, 1 light, 2 dark

  double fontSize = 24;
  double lineHeight = 1.55;
  ThemeMode themeMode = ThemeMode.system;

  SharedPreferences? _prefs;

  Future<void> loadFromPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    final p = _prefs!;

    fontSize = p.getDouble(_kFontSize) ?? 24;
    lineHeight = p.getDouble(_kLineHeight) ?? 1.55;

    final mode = p.getInt(_kThemeMode) ?? 0;
    themeMode = switch (mode) {
      1 => ThemeMode.light,
      2 => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    notifyListeners();
  }

  Future<void> _save() async {
    _prefs ??= await SharedPreferences.getInstance();
    final p = _prefs!;
    await p.setDouble(_kFontSize, fontSize);
    await p.setDouble(_kLineHeight, lineHeight);
    await p.setInt(
      _kThemeMode,
      themeMode == ThemeMode.light
          ? 1
          : themeMode == ThemeMode.dark
              ? 2
              : 0,
    );
  }

  void setFontSize(double v) {
    fontSize = v;
    notifyListeners();
    _save();
  }

  void setLineHeight(double v) {
    lineHeight = v;
    notifyListeners();
    _save();
  }

  void setThemeMode(ThemeMode v) {
    themeMode = v;
    notifyListeners();
    _save();
  }
}

final AppSettings settings = AppSettings();

/// ----------------------
/// FAVORITES (global + persisted)
/// ----------------------
class FavoritesStore extends ChangeNotifier {
  static const _kFavNumbers = 'favNumbers';

  final Set<int> _favNumbers = {};
  SharedPreferences? _prefs;

  bool isFav(int number) => _favNumbers.contains(number);

  List<int> get allNumbers => _favNumbers.toList()..sort();

  Future<void> loadFromPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    final list = _prefs!.getStringList(_kFavNumbers) ?? const [];

    _favNumbers
      ..clear()
      ..addAll(list.map((e) => int.tryParse(e)).whereType<int>());

    notifyListeners();
  }

  Future<void> _save() async {
    _prefs ??= await SharedPreferences.getInstance();
    final list = _favNumbers.map((e) => e.toString()).toList();
    await _prefs!.setStringList(_kFavNumbers, list);
  }

  void toggle(int number) {
    if (_favNumbers.contains(number)) {
      _favNumbers.remove(number);
    } else {
      _favNumbers.add(number);
    }
    notifyListeners();
    _save();
  }
}

final FavoritesStore favorites = FavoritesStore();

//
ThemeData hymnalLightTheme() {
  const primary = Color(0xFF1F3C88);
  const secondary = Color(0xFF3F6AE1);

  // Soft “premium” whites (still looks white, but not harsh)
  const surface = Color(0xFFFFFFFF);
  const scaffold = Color(0xFFFFFFFF);
  const softFill = Color(0xFFF5F7FF); // used for inputs / subtle surfaces

  final cs = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.light,
    primary: primary,
    secondary: secondary,
    surface: surface,
  ).copyWith(
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: const Color(0xFF121212),
    error: Colors.red,
    onError: Colors.white,
    // M3 “container” color used by some widgets
    surfaceContainerHighest: softFill,
    outline: const Color(0x14000000),
  );

  return ThemeData(
    useMaterial3: false,
    colorScheme: cs,
    scaffoldBackgroundColor: scaffold,

    // ✅ absolutely NO divider lines anywhere
    dividerTheme: const DividerThemeData(
      thickness: 0,
      space: 0,
      color: Colors.transparent,
    ),

    // Type
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontWeight: FontWeight.w800),
      titleMedium: TextStyle(fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontWeight: FontWeight.w500),
      bodyMedium: TextStyle(fontWeight: FontWeight.w500),
    ).apply(
      bodyColor: cs.onSurface,
      displayColor: cs.onSurface,
    ),

    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: scaffold,
      foregroundColor: primary,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: primary,
      ),
    ),

    // ✅ subtle surfaces, no borders
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: primary,
      textColor: cs.onSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: softFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0x00000000)), // ✅ no border
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 1.4),
      ),
      hintStyle: const TextStyle(color: Color(0xFF6B7280)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),

    // Buttons feel “premium”
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 72,
      backgroundColor: scaffold,
      indicatorColor: primary.withValues(alpha: 0.12),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(size: 25, color: primary);
        }
        return const IconThemeData(size: 23, color: Color(0xFF6B7280));
      }),
    ),
  );
}

ThemeData hymnalDarkTheme() {
  const primary = Color(0xFF90CAF9);
  const secondary = Color(0xFF4FA3FF);

  const scaffold = Color(0xFF0B1220); // deep navy
  const surface = Color(0xFF0B1220);
  const panel = Color(0xFF101A2E); // cards / inputs / controls

  final cs = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.dark,
    primary: primary,
    secondary: secondary,
    surface: surface,
  ).copyWith(
    onPrimary: const Color(0xFF0B1220),
    onSecondary: const Color(0xFF06101F),
    onSurface: const Color(0xFFEAF0FF),
    error: const Color(0xFFFF6B6B),
    onError: const Color(0xFF1A0B0B),
    surfaceContainerHighest: panel,
    outline: const Color(0x00000000),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: scaffold,

    // ✅ NO divider lines anywhere
    dividerTheme: const DividerThemeData(
      thickness: 0,
      space: 0,
      color: Colors.transparent,
    ),

    textTheme: const TextTheme(
      titleLarge: TextStyle(fontWeight: FontWeight.w800),
      titleMedium: TextStyle(fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontWeight: FontWeight.w500),
      bodyMedium: TextStyle(fontWeight: FontWeight.w500),
    ).apply(
      bodyColor: cs.onSurface,
      displayColor: cs.onSurface,
    ),

    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: scaffold,
      foregroundColor: Color(0xFFEAF0FF),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Color(0xFFEAF0FF),
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: primary,
      textColor: cs.onSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panel,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0x00000000)), // ✅ no border
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 1.4),
      ),
      hintStyle: const TextStyle(color: Color(0xFF96A4C3)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 72,
      backgroundColor: scaffold,
      indicatorColor: primary.withValues(alpha: 0.18),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(size: 25, color: primary);
        }
        return const IconThemeData(size: 23, color: Color(0xFF96A4C3));
      }),
    ),
  );
}

//
class SdaLusogaHymnalApp extends StatelessWidget {
  const SdaLusogaHymnalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (_, __) {
        return MaterialApp(
          title: 'SDA Lusoga Hymnal',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: hymnalLightTheme(),
          darkTheme: hymnalDarkTheme(),
          home: const AppShell(),
        );
      },
    );
  }
}

/// ----------------------
/// MODEL
/// ----------------------
class SongMeta {
  final String? meter;
  final String? author;
  final String? tune;
  final String? by;
  final String? doh;

  const SongMeta({
    this.meter,
    this.author,
    this.tune,
    this.by,
    this.doh,
  });

  factory SongMeta.fromJson(Map<String, dynamic> json) {
    return SongMeta(
      meter: json['meter']?.toString(),
      author: json['author']?.toString(),
      tune: json['tune']?.toString(),
      by: json['by']?.toString(),
      doh: json['doh']?.toString(),
    );
  }

  bool get isEmpty =>
      (meter == null || meter!.trim().isEmpty) &&
      (author == null || author!.trim().isEmpty) &&
      (tune == null || tune!.trim().isEmpty) &&
      (by == null || by!.trim().isEmpty) &&
      (doh == null || doh!.trim().isEmpty);
}

class Song {
  final int number;
  final String title;
  final String lyrics;
  final String? reference;
  final SongMeta? meta;

  const Song({
    required this.number,
    required this.title,
    required this.lyrics,
    this.reference,
    this.meta,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    final metaJson = json['meta'];
    return Song(
      number: (json['number'] as num).toInt(),
      title: (json['title'] ?? '').toString(),
      lyrics: (json['lyrics'] ?? '').toString(),
      reference: json['reference']?.toString(),
      meta:
          metaJson is Map<String, dynamic> ? SongMeta.fromJson(metaJson) : null,
    );
  }
}

/// ----------------------
/// LOAD FROM JSON ASSET
/// ----------------------
Future<List<Song>> loadSongs() async {
  try {
    final raw = await rootBundle.loadString('assets/hymns/lusoga_hymns.json');
    final decoded = jsonDecode(raw);

    if (decoded is! List) {
      debugPrint('❌ hymns json is not a List');
      return const [];
    }

    final songs = <Song>[];

    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        try {
          songs.add(Song.fromJson(item));
        } catch (e) {
          debugPrint('❌ Bad song item skipped: $e\n$item');
        }
      }
    }

    songs.sort((a, b) => a.number.compareTo(b.number));
    debugPrint('✅ Loaded hymns: ${songs.length}');
    return songs;
  } catch (e, st) {
    debugPrint('❌ Failed to load hymns JSON: $e');
    debugPrint('$st');
    return const [];
  }
}

/// ----------------------
/// BOTTOM NAV SHELL
/// ----------------------
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  late final Future<List<Song>> _songsFuture = loadSongs();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Song>>(
      future: _songsFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load hymns:\n${snap.error}'),
              ),
            ),
          );
        }

        final songs = snap.data ?? const [];

        return Scaffold(
          body: IndexedStack(
            index: index,
            children: [
              HomeJumpScreen(allSongs: songs), // ✅ FIXED
              SongsHome(allSongs: songs), // ✅ FIXED
              FavoritesScreen(allSongs: songs), // ✅ FIXED
              const SettingsScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => index = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.apps_rounded), label: 'Home'),
              NavigationDestination(
                  icon: Icon(Icons.library_music), label: 'Songs'),
              NavigationDestination(icon: Icon(Icons.star), label: 'Favorites'),
              NavigationDestination(
                  icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        );
      },
    );
  }
}

// jump
class HomeJumpScreen extends StatefulWidget {
  final List<Song> allSongs;

  const HomeJumpScreen({
    super.key,
    required this.allSongs,
  });

  @override
  State<HomeJumpScreen> createState() => _HomeJumpScreenState();
}

class _HomeJumpScreenState extends State<HomeJumpScreen> {
  final _controller = TextEditingController();

  void _tapDigit(String d) {
    final text = _controller.text;
    if (text.length >= 4) return; // safety
    setState(() => _controller.text = text + d);
  }

  void _backspace() {
    final text = _controller.text;
    if (text.isEmpty) return;
    setState(() => _controller.text = text.substring(0, text.length - 1));
  }

  void _openHymn() {
    final n = int.tryParse(_controller.text.trim());
    if (n == null) return;

    final songs = widget.allSongs;
    final idx = songs.indexWhere((s) => s.number == n);

    if (idx == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hymn #$n not found yet')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SongDetails(
          song: songs[idx],
          allSongs: songs,
          index: idx,
        ),
      ),
    ).then((_) {
      _controller.clear(); // ✅ reset text
      setState(() {}); // ✅ refresh UI
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canOpen = int.tryParse(_controller.text.trim()) != null;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'SDA Lusoga Hymnal',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: [
            // header input card
            Card(
              elevation: 0,
              color: scheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.25)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jump to hymn',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.numbers),
                              hintText: 'Enter hymn number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // keypad expands safely on small screens
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  const spacing = 10.0;
                  const buttonH = 52.0;
                  const bottomGap = 14.0;

                  const rows = 4;
                  const cols = 3;

                  final tileW = (c.maxWidth - spacing * (cols - 1)) / cols;

                  final availableForGrid = c.maxHeight - buttonH - bottomGap;

                  final tileHByHeight =
                      (availableForGrid - spacing * (rows - 1)) / rows;

                  final tileHByWidth = tileW * 0.72;

                  final tileH = tileHByHeight < tileHByWidth
                      ? tileHByHeight
                      : tileHByWidth;

                  Widget key(String label,
                      {VoidCallback? onTap, IconData? icon}) {
                    return SizedBox(
                      width: tileW,
                      height: tileH,
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: const BorderSide(
                            color: Colors.black54, // ✅ black border
                            width: 1.2,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onPressed: onTap,
                        child:
                            icon != null ? Icon(icon, size: 26) : Text(label),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: GridView.count(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          crossAxisCount: 3, // ✅ always 3 per row
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          childAspectRatio: tileW / tileH,
                          children: [
                            key('1', onTap: () => _tapDigit('1')),
                            key('2', onTap: () => _tapDigit('2')),
                            key('3', onTap: () => _tapDigit('3')),
                            key('4', onTap: () => _tapDigit('4')),
                            key('5', onTap: () => _tapDigit('5')),
                            key('6', onTap: () => _tapDigit('6')),
                            key('7', onTap: () => _tapDigit('7')),
                            key('8', onTap: () => _tapDigit('8')),
                            key('9', onTap: () => _tapDigit('9')),

                            // ✅ centered last row: [empty] [0] [⌫]
                            const SizedBox.shrink(),
                            key('0', onTap: () => _tapDigit('0')),
                            key('',
                                icon: Icons.backspace_outlined,
                                onTap: _backspace),
                          ],
                        ),
                      ),
                      const SizedBox(height: bottomGap),
                      SizedBox(
                        width: double.infinity,
                        height: buttonH,
                        child: FilledButton(
                          onPressed: canOpen ? _openHymn : null,
                          child: const Text(
                            'Open Hymn',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// ----------------------
/// HOME (Songs list)
/// ----------------------
class SongsHome extends StatefulWidget {
  final List<Song> allSongs;

  const SongsHome({
    super.key,
    required this.allSongs,
  });

  @override
  State<SongsHome> createState() => _SongsHomeState();
}

class _SongsHomeState extends State<SongsHome> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final songs = widget.allSongs; // ✅ Use what AppShell gives you
    final q = query.trim().toLowerCase();

    final filtered = songs.where((s) {
      if (q.isEmpty) return true;
      return s.title.toLowerCase().contains(q) ||
          s.number.toString().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: scheme.surface, // ✅ more premium than hard blue
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'SDA Lusoga Hymnal',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.2),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          /// SEARCH
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.20),
                    width: 1.1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search,
                        size: 20,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.8)),

                    const SizedBox(width: 8),

                    /// SEARCH INPUT
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search hymn',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (v) => setState(() => query = v),
                      ),
                    ),

                    /// COUNTER INSIDE SAME BAR
                    Text(
                      '${filtered.length}/${songs.length}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),

                    if (query.trim().isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => query = ''),
                      ),
                  ],
                ),
              ),
            ),
          ),

          /// EMPTY
          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No hymns found.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          else

            /// LIST with premium dividers
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final song = filtered[i];

                  // ✅ find real index in full list for next/prev navigation
                  final realIndex =
                      songs.indexWhere((s) => s.number == song.number);

                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 2),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              scheme.primary.withValues(alpha: 0.12),
                          child: Text(
                            song.number.toString(),
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        title: Text(
                          song.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right,
                            color: scheme.onSurfaceVariant),
                        onTap: () {
                          if (realIndex == -1) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SongDetails(
                                song: songs[realIndex],
                                allSongs:
                                    songs, // ✅ full list for prev/next arrows
                                index: realIndex,
                              ),
                            ),
                          );
                        },
                      ),

                      // divider starts after the number bubble
                      Padding(
                        padding: const EdgeInsets.only(left: 65),
                        child: Divider(
                          height: 1,
                          thickness: 2.5,
                          color: scheme.outlineVariant.withValues(alpha: 0.20),
                        ),
                      ),
                    ],
                  );
                },
                childCount: filtered.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ],
      ),
    );
  }
}

/// ----------------------
/// FAVORITES TAB
/// ----------------------

class FavoritesScreen extends StatelessWidget {
  final List<Song> allSongs;

  const FavoritesScreen({
    super.key,
    required this.allSongs,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: favorites,
      builder: (_, __) {
        final favSet = favorites.allNumbers.toSet();

        final favSongs = allSongs
            .where((s) => favSet.contains(s.number))
            .toList()
          ..sort((a, b) => a.number.compareTo(b.number));

        return Scaffold(
          appBar: AppBar(title: const Text('Favorites')),
          body: favSongs.isEmpty
              ? Center(
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 1),
                    elevation: 0,
                    color: scheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'No favorites yet.\nTap the ⭐ on a hymn to save it here.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  itemCount: favSongs.length,
                  separatorBuilder: (_, __) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    child: Divider(
                      height: 1,
                      thickness: 0.8,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  itemBuilder: (context, i) {
                    final song = favSongs[i];

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              scheme.primary.withValues(alpha: 0.12),
                          child: Text(
                            song.number.toString(),
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          song.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove from favorites',
                          icon: const Icon(Icons.star),
                          onPressed: () => favorites.toggle(song.number),
                        ),
                        onTap: () {
                          final idx = allSongs
                              .indexWhere((s) => s.number == song.number);
                          if (idx == -1) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SongDetails(
                                song: allSongs[idx],
                                allSongs: allSongs,
                                index: idx,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

/// ----------------------
/// SETTINGS TAB
/// ----------------------
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SettingsSheet(),
        ],
      ),
    );
  }
}

/// ----------------------
/// DETAILS (Pinned header +
class SongDetails extends StatefulWidget {
  final Song song;
  final List<Song> allSongs;
  final int index;

  const SongDetails({
    super.key,
    required this.song,
    required this.allSongs,
    required this.index,
  });

  @override
  State<SongDetails> createState() => _SongDetailsState();
}

class _SongDetailsState extends State<SongDetails> {
  void _goPrev() {
    if (widget.index <= 0) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SongDetails(
          song: widget.allSongs[widget.index - 1],
          allSongs: widget.allSongs,
          index: widget.index - 1,
        ),
      ),
    );
  }

  void _goNext() {
    if (widget.index >= widget.allSongs.length - 1) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SongDetails(
          song: widget.allSongs[widget.index + 1],
          allSongs: widget.allSongs,
          index: widget.index + 1,
        ),
      ),
    );
  }

  String _bestReferenceLine(Song s) {
    final ref = s.reference?.trim();
    if (ref != null && ref.isNotEmpty) return ref;
    return 'Reference not set';
  }

  _RightInfo _bestRightInfo(SongMeta? meta) {
    final meter = (meta?.meter ?? '').trim();
    final author = (meta?.author ?? '').trim();
    final tune = (meta?.tune ?? '').trim();
    final by = (meta?.by ?? '').trim();
    final doh = (meta?.doh ?? '').trim();

    return _RightInfo(
      topLeft: meter.isEmpty ? '—' : meter,
      topRight: author.isEmpty ? '—' : author,
      midLeft: tune.isEmpty ? '—' : tune,
      midRight: by.isEmpty ? '—' : by,
      bottom: doh.isEmpty ? 'Doh is —' : 'Doh is $doh',
    );
  }

  @override
  Widget build(BuildContext context) {
    const maxPageWidth = 920.0;

    final headerRef = _bestReferenceLine(widget.song);
    final rightInfo = _bestRightInfo(widget.song.meta);

    final scheme = Theme.of(context).colorScheme;

    final canPrev = widget.index > 0;
    final canNext = widget.index < widget.allSongs.length - 1;

    const lyricsBg = Colors.white;
    const topBg = Color(0xFFF3F5F9);

    return Scaffold(
      backgroundColor: lyricsBg,
      appBar: AppBar(
        backgroundColor: topBg,
        foregroundColor: scheme.primary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,

        automaticallyImplyLeading: false, // ✅ removes back arrow
        toolbarHeight: 0,

        // ❌ Removed title completely
        // title: const Text('SDA Lusoga Hymnal'),

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Container(
            color: topBg,
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width < 600
                      ? double.infinity
                      : 920,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HeaderCardLikeScreenshot(
                      song: widget.song,
                      headerRef: headerRef,
                      rightInfo: rightInfo,
                    ),
                    const SizedBox(height: 4),
                    _ControlsRow(
                      song: widget.song,
                      canPrev: canPrev,
                      canNext: canNext,
                      onPrev: _goPrev,
                      onNext: _goNext,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        color: Colors.white, // ← ADD THIS LINE
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxPageWidth),
            child: Scrollbar(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                  children: [
                    Container(
                      color: Colors.white, // forces pure white behind lyrics
                      child: buildLyricsView(context, widget.song.lyrics),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCardLikeScreenshot extends StatelessWidget {
  final Song song;
  final String headerRef;
  final _RightInfo rightInfo;

  const _HeaderCardLikeScreenshot({
    required this.song,
    required this.headerRef,
    required this.rightInfo,
  });

  String _clean(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty ? '—' : t;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w900,
          fontSize: 13,
          height: 1,
          color: scheme.onSurface,
        );

    final refStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 10,
          height: 1,
          color: scheme.onSurface.withValues(alpha: 0.70),
        );

    final rightStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w900,
          fontSize: 10,
          height: 1,
          color: scheme.onSurface,
        );

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final rightW = (w * 0.36).clamp(70.0, 130.0);

        // ✅ classy cool-gray / subtle blue tint gradient (reads premium on white)
        const g1 = Color(0xFFF7F8FB); // very light
        const g2 = Color(0xFFEFF2F9); // slightly deeper
        const g3 = Color(0xFFFDFDFE); // lift highlight

        return SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [g3, g1, g2],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.10),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${song.number}    ${song.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          headerRef,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: refStyle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: rightW,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _RightPairRow(
                          left: _clean(rightInfo.topLeft),
                          right: _clean(rightInfo.topRight),
                          style: rightStyle,
                        ),
                        const SizedBox(height: 2),
                        _RightPairRow(
                          left: _clean(rightInfo.midLeft),
                          right: _clean(rightInfo.midRight),
                          style: rightStyle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _clean(rightInfo.bottom),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: rightStyle?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Everything else (RightPairRow, ControlsRow, NavSquare, HeaderActionsScreenshotStyle, RightInfo)
// can remain as you already have it.

class _RightPairRow extends StatelessWidget {
  final String left;
  final String right;
  final TextStyle? style;

  const _RightPairRow({
    required this.left,
    required this.right,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: style,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            style: style,
          ),
        ),
      ],
    );
  }
}

class _ControlsRow extends StatelessWidget {
  final Song song;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _ControlsRow({
    required this.song,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NavSquare(
          enabled: canPrev,
          icon: Icons.chevron_left,
          onTap: onPrev,
        ),
        const SizedBox(width: 8),
        Expanded(child: _HeaderActionsScreenshotStyle(song: song)),
        const SizedBox(width: 8),
        _NavSquare(
          enabled: canNext,
          icon: Icons.chevron_right,
          onTap: onNext,
        ),
      ],
    );
  }
}

class _NavSquare extends StatelessWidget {
  final bool enabled;
  final IconData icon;
  final VoidCallback onTap;

  const _NavSquare({
    required this.enabled,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surfaceContainerHighest;
    final fg = scheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.45,
        child: Ink(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: const Border.fromBorderSide(
              BorderSide(color: Colors.black, width: 1),
            ),
          ),
          child: Icon(icon, size: 18, color: fg),
        ),
      ),
    );
  }
}

// unchanged
class _HeaderActionsScreenshotStyle extends StatelessWidget {
  final Song song;
  const _HeaderActionsScreenshotStyle({required this.song});

  String shareText(Song s) {
    final header = '${s.number}. ${s.title}';
    final lyrics =
        s.lyrics.trim().isEmpty ? 'Lyrics not added yet.' : s.lyrics.trim();
    return '$header\n\n$lyrics\n\n— SDA Lusoga Hymnal';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget pill({
      required String label,
      required VoidCallback onTap,
      IconData? icon,
    }) {
      final bg = scheme.surfaceContainerHighest;
      final fg = scheme.onSurface;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Ink(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: const Border.fromBorderSide(
                BorderSide(color: Colors.black, width: 0.8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: fg),
                  const SizedBox(width: 2),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: favorites,
      builder: (_, __) {
        final isFav = favorites.isFav(song.number);

        return Wrap(
          spacing: 2,
          runSpacing: 1,
          alignment: WrapAlignment.center,
          children: [
            pill(
              label: 'Fav',
              icon: isFav ? Icons.favorite : Icons.favorite_border,
              onTap: () => favorites.toggle(song.number),
            ),
            pill(
              label: 'Copy',
              icon: Icons.content_copy,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: shareText(song)));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Copied!'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  );
                }
              },
            ),
            pill(
              label: 'Share',
              icon: Icons.ios_share,
              onTap: () => Share.share(shareText(song)),
            ),
          ],
        );
      },
    );
  }
}

class _RightInfo {
  final String? topLeft;
  final String? topRight;
  final String? midLeft;
  final String? midRight;
  final String? bottom;

  const _RightInfo({
    this.topLeft,
    this.topRight,
    this.midLeft,
    this.midRight,
    this.bottom,
  });
}

/// ----------------------
/// LYRICS RENDERING (Verse + Chorus highlighting)
/// ----------------------
class LyricsBlock {
  final bool isChorus;
  final String text;
  const LyricsBlock({required this.isChorus, required this.text});
}

List<LyricsBlock> parseLyricsBlocks(String raw) {
  final text = raw.replaceAll('\r\n', '\n').trim();
  if (text.isEmpty) return const [];

  bool isChorusHeader(String line) {
    final l = line.trim().toLowerCase();
    return l.startsWith('chorus:') ||
        l.startsWith('refrain:') ||
        l.startsWith('ddoboozi :');
  }

  final lines = text.split('\n');

  final blocks = <List<String>>[];
  var current = <String>[];

  for (final line in lines) {
    if (line.trim().isEmpty) {
      if (current.isNotEmpty) {
        blocks.add(current);
        current = <String>[];
      }
    } else {
      current.add(line);
    }
  }
  if (current.isNotEmpty) blocks.add(current);

  final out = <LyricsBlock>[];

  for (final b in blocks) {
    final first = b.first.trim();
    if (isChorusHeader(first)) {
      final rest = b.skip(1).join('\n').trim();
      if (rest.isNotEmpty) {
        out.add(LyricsBlock(isChorus: true, text: rest));
      }
    } else {
      out.add(LyricsBlock(isChorus: false, text: b.join('\n').trim()));
    }
  }

  return out;
}

Widget buildLyricsView(BuildContext context, String raw) {
  final scheme = Theme.of(context).colorScheme;
  final isDark = scheme.brightness == Brightness.dark;
  final blocks = parseLyricsBlocks(raw);

  if (raw.trim().isEmpty) {
    return Text(
      'Lyrics not added yet.',
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.85),
          ),
    );
  }

  return AnimatedBuilder(
    animation: settings,
    builder: (_, __) {
      final lyricsColor =
          scheme.onSurface.withValues(alpha: isDark ? 0.93 : 0.90);

      final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: settings.fontSize,
            height: settings.lineHeight, // ✅ use your setting directly
            fontWeight: FontWeight.w500,
            color: lyricsColor,
          );

      if (blocks.isEmpty) return Text(raw, style: baseStyle);

      Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.primary.withValues(alpha: isDark ? 0.90 : 0.82),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.35,
          );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in blocks) ...[
            if (b.isChorus) ...[
              const SizedBox(height: 8),
              Text(
                'Chorus',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
              ),

              const SizedBox(height: 5),

              // ✅ chorus block: slight indent + subtle left rail
              // ✅ same as verse number width
              _StanzaView(
                text: b.text,
                style: baseStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: lyricsColor.withValues(alpha: 0.96),
                  // optional hymnal feel
                ),
                showVerseNumber: false,
              ),
            ] else ...[
              _StanzaView(text: b.text, style: baseStyle),
            ],
            const SizedBox(height: 25),
          ],
        ],
      );
    },
  );
}

class _StanzaView extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool showVerseNumber;

  const _StanzaView({
    required this.text,
    this.style,
    this.showVerseNumber = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final rawLines = text.split('\n');
    if (rawLines.isEmpty) return Text(text, style: style);

    final firstLine = rawLines.first.trim();
    final match = RegExp(r'^(\d+)[\.\)]\s*(.*)').firstMatch(firstLine);

    // Not a numbered stanza OR numbering disabled
    if (match == null || !showVerseNumber) {
      return Text(
        text,
        style: style?.copyWith(height: settings.lineHeight),
      );
    }

    final number = match.group(1)!;
    final firstText = (match.group(2) ?? '').trim();
    final rest = rawLines.skip(1).join('\n').trim();

    final verseColor = scheme.primary.withValues(alpha: isDark ? 0.78 : 0.72);

    // ✅ Build ONE rich text block so number is inline with first line
    return RichText(
      text: TextSpan(
        style: style?.copyWith(height: settings.lineHeight),
        children: [
          TextSpan(
            text: '$number. ',
            style: style?.copyWith(
              fontWeight: FontWeight.w900,
              color: verseColor,
            ),
          ),
          TextSpan(
            text: [
              if (firstText.isNotEmpty) firstText,
              if (rest.isNotEmpty) '\n$rest',
            ].join(),
          ),
        ],
      ),
    );
  }
}

/// ----------------------
/// SETTINGS SHEET
/// ----------------------
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final font = settings.fontSize.clamp(14.0, 40.0);
    return SafeArea(
      child: AnimatedBuilder(
        animation: settings,
        builder: (_, __) {
          return Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reading settings',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  Text('Font size: ${settings.fontSize.toStringAsFixed(0)}'),
                  Slider(
                    value: font,
                    min: 14,
                    max: 40,
                    divisions: 26, // 40 - 14 = 26 steps
                    onChanged: settings.setFontSize,
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'Line spacing: ${settings.lineHeight.toStringAsFixed(2)}'),
                  Slider(
                    value: settings.lineHeight,
                    min: 1.20,
                    max: 2.00,
                    divisions: 16,
                    onChanged: settings.setLineHeight,
                  ),
                  const SizedBox(height: 10),
                  Text('Theme', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.brightness_auto)),
                      ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode)),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode)),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (set) =>
                        settings.setThemeMode(set.first),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Preview: Katonda ye mulungi. (This is a sample preview.)',
                        style: TextStyle(
                            fontSize: settings.fontSize,
                            height: settings.lineHeight),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ----------------------
/// JUMP TO DIALOG
/// ----------------------
class JumpToSheet extends StatefulWidget {
  const JumpToSheet({super.key});

  @override
  State<JumpToSheet> createState() => _JumpToSheetState();
}

class _JumpToSheetState extends State<JumpToSheet> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jump to hymn',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter hymn number (e.g. 73)',
              prefixIcon: const Icon(Icons.numbers),
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.25)),
              ),
            ),
            onSubmitted: (_) => _open(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _open,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open hymn'),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Tip: You can also search from the Songs tab.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.7),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _open() {
    final n = int.tryParse(controller.text.trim());
    if (n == null) return;
    Navigator.pop(context, n);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
