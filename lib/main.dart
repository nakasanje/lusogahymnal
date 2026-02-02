import 'dart:convert';
import 'package:flutter/material.dart';
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

        final songs = (snap.data ?? [])..sort((a, b) => a.number.compareTo(b.number));

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
                          borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.25)),
                        ),
                      ),
                      onSubmitted: (_) => _openFromNumber(context, songs),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => _openFromNumber(context, songs),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.play_circle_outline, color: scheme.primary),
                      title: const Text('Continue reading'),
                      subtitle: Text(lastSong == null
                          ? 'Open any hymn to enable this.'
                          : '#${lastSong.number} — ${lastSong.title}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: lastSong == null
    ? null
    : () => _openSong(context, songs, lastSong!.number),

                    ),
                    Divider(height: 1, color: scheme.outlineVariant.withOpacity(0.35)),
                    ListTile(
                      leading: Icon(Icons.shuffle_rounded, color: scheme.primary),
                      title: const Text('Random hymn'),
                      subtitle: const Text('Surprise me'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        if (songs.isEmpty) return;
                        final picked = (songs.toList()..shuffle()).first;
                        _openSong(context, songs, picked.number);
                      },
                    ),
                    Divider(height: 1, color: scheme.outlineVariant.withOpacity(0.35)),
                    ListTile(
                      leading: Icon(Icons.star_outline, color: scheme.primary),
                      title: const Text('Open favorites'),
                      subtitle: const Text('Your saved hymns'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // Switch to Favorites tab (index = 2)
                        final appShell = context.findAncestorStateOfType<_AppShellState>();
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
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.75),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _premiumAppBar(BuildContext context, {required String title}) {
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
        child: Divider(height: 1, color: scheme.outlineVariant.withOpacity(0.35)),
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

  Future<void> _openSong(BuildContext context, List<Song> songs, int number) async {
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

  double fontSize = 18;
  double lineHeight = 1.55;
  ThemeMode themeMode = ThemeMode.system;

  SharedPreferences? _prefs;

  Future<void> loadFromPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    final p = _prefs!;

    fontSize = p.getDouble(_kFontSize) ?? 18;
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

          // ✅ LIGHT THEME
          theme: ThemeData(
  useMaterial3: true,

  // ✅ Premium seed (not too dark, not too neon)
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1E7A3E),
    brightness: Brightness.light,
  ),

  // ✅ Clean warm background (looks expensive)
  scaffoldBackgroundColor: const Color(0xFFF6F6F2),

  // ✅ Global typography feel
  textTheme: const TextTheme(
    titleLarge: TextStyle(fontWeight: FontWeight.w800),
    titleMedium: TextStyle(fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(fontWeight: FontWeight.w500),
    bodyMedium: TextStyle(fontWeight: FontWeight.w500),
  ),

  // ✅ AppBar that “gives”
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: Color(0xFFF6F6F2),
    foregroundColor: Color(0xFF121212),
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: Color(0xFF121212),
      letterSpacing: 0.2,
    ),
  ),

  // ✅ Premium separators
  dividerTheme: DividerThemeData(
    thickness: 1,
    space: 1,
    color: Colors.black.withOpacity(0.08),
  ),

  // ✅ Cards consistent (no heavy borders)
  cardTheme: CardTheme(
  elevation: 0,
  color: Colors.white.withOpacity(0.85),
  surfaceTintColor: Colors.transparent,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  ),
  ),

  // ✅ List tiles look “iOS premium”
  listTileTheme: ListTileThemeData(
    iconColor: const Color(0xFF1E7A3E),
    textColor: const Color(0xFF121212),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  ),

  // ✅ Input (search box) style
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white.withOpacity(0.75),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF1E7A3E), width: 1.2),
    ),
    hintStyle: TextStyle(color: Colors.black.withOpacity(0.45)),
  ),

  // ✅ Bottom Navigation (better colors + better contrast)
  navigationBarTheme: NavigationBarThemeData(
    elevation: 0,
    height: 72,
    backgroundColor: Color.fromARGB(255, 155, 155, 152),
    indicatorColor: Color.fromARGB(255, 23, 92, 47).withOpacity(0.14),
    labelTextStyle: const WidgetStatePropertyAll(
      TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
    ),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(size: 26, color: Color(0xFF1E7A3E));
      }
      return IconThemeData(size: 24, color: Colors.black.withOpacity(0.45));
    }),
  ),
),

darkTheme: ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1E7A3E),
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF0F1111),

  appBarTheme: const AppBarTheme(
    centerTitle: true,
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: Color.fromARGB(255, 5, 5, 5),
    foregroundColor: Color.fromARGB(255, 182, 179, 179),
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: Colors.white,
    ),
  ),

  navigationBarTheme: NavigationBarThemeData(
    elevation: 0,
    height: 72,
    backgroundColor: const Color.fromARGB(255, 5, 5, 5),
    indicatorColor: const Color(0xFF1E7A3E).withOpacity(0.22),
    labelTextStyle: const WidgetStatePropertyAll(
      TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
    ),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(size: 26, color: Color(0xFF45D07B));
      }
      return IconThemeData(size: 24, color: Colors.white70);
    }),
  ),
),


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
      meta: metaJson is Map<String, dynamic> ? SongMeta.fromJson(metaJson) : null,
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
              HomeJumpScreen(allSongs: songs),     // ✅ FIXED
              SongsHome(allSongs: songs),          // ✅ FIXED
              FavoritesScreen(allSongs: songs),    // ✅ FIXED
              const SettingsScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => index = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.apps_rounded), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.library_music), label: 'Songs'),
              NavigationDestination(icon: Icon(Icons.star), label: 'Favorites'),
              NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
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

  void _clear() => setState(() => _controller.clear());

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
    );
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
                side: BorderSide(color: scheme.outlineVariant.withOpacity(0.25)),
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

      final tileH = tileHByHeight < tileHByWidth ? tileHByHeight : tileHByWidth;

      Widget key(String label, {VoidCallback? onTap, IconData? icon}) {
        return SizedBox(
          width: tileW,
          height: tileH,
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            onPressed: onTap,
            child: icon != null ? Icon(icon, size: 26) : Text(label),
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
                key('', icon: Icons.backspace_outlined, onTap: _backspace),
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
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
      return s.title.toLowerCase().contains(q) || s.number.toString().contains(q);
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Card(
                elevation: 0,
                color: scheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: scheme.outlineVariant.withOpacity(0.25)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
                            hintText: 'Search hymn number or title',
                            border: InputBorder.none,
                            suffixIcon: query.trim().isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear',
                                    icon: const Icon(Icons.close),
                                    onPressed: () => setState(() => query = ''),
                                  ),
                          ),
                          onChanged: (v) => setState(() => query = v),
                        ),
                      ),
                      Text(
                        '${filtered.length}/${songs.length}',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
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
                  final realIndex = songs.indexWhere((s) => s.number == song.number);

                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: scheme.primary.withOpacity(0.12),
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
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                        onTap: () {
                          if (realIndex == -1) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SongDetails(
                                song: songs[realIndex],
                                allSongs: songs, // ✅ full list for prev/next arrows
                                index: realIndex,
                              ),
                            ),
                          );
                        },
                      ),

                      // divider starts after the number bubble
                      Padding(
                        padding: const EdgeInsets.only(left: 72),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: scheme.outlineVariant.withOpacity(0.35),
                        ),
                      ),
                    ],
                  );
                },
                childCount: filtered.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
                    elevation: 0,
                    color: scheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No favorites yet.\nTap the ⭐ on a hymn to save it here.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  itemCount: favSongs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final song = favSongs[i];

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: scheme.primary.withOpacity(0.12),
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
                          final idx =
                              allSongs.indexWhere((s) => s.number == song.number);
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
/// DETAILS (Pinned header + lyrics)
/// ----------------------
/// ----------------------
class SongDetails extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final headerRef = _bestReferenceLine(song);
    final rightInfo = _bestRightInfo(song.meta);

    void goPrev() {
      if (index <= 0) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SongDetails(
            song: allSongs[index - 1],
            allSongs: allSongs,
            index: index - 1,
          ),
        ),
      );
    }

    void goNext() {
      if (index >= allSongs.length - 1) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SongDetails(
            song: allSongs[index + 1],
            allSongs: allSongs,
            index: index + 1,
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          /// ✅ PINNED HEADER (no back arrow) + Prev/Next + icons slightly lower
          SliverPersistentHeader(
            pinned: true,
            delegate: PinnedHeaderDelegate(
              height: 118,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Card(
                  elevation: 0,
                  color: scheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: scheme.outlineVariant.withOpacity(0.25)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Stack(
                      children: [
                        // MAIN ROW (Left + Right)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // LEFT SIDE
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${song.number}  ${song.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          height: 1,
                                          
                                        ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    headerRef,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontSize: 10,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color
                                              ?.withOpacity(0.7),
                                        ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 10),

                            // RIGHT SIDE
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _RightRow(left: rightInfo.topLeft, right: rightInfo.topRight),
                                const SizedBox(height: 0.1),
                                _RightRow(left: rightInfo.midLeft, right: rightInfo.midRight),
                                const SizedBox(height: 4),
                                Text(
                                  rightInfo.bottom ?? 'Doh is —',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        color: scheme.onSurface.withOpacity(0.85),
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // ◀ PREVIOUS (bottom-left)
                        Positioned(
                          left: 70,
                          bottom: 0,
                          top:35,
                          child: IconButton(
                            tooltip: 'Previous hymn',
                            icon: const Icon(Icons.arrow_left, size: 28),
                            onPressed: index > 0 ? goPrev : null,
                          ),
                        ),

                        // ▶ NEXT (bottom-right)
                        Positioned(
                          right: 70,
                          bottom: 0,
                          top:35,
                          child: IconButton(
                            tooltip: 'Next hymn',
                            icon: const Icon(Icons.arrow_right, size: 28),
                            onPressed: index < allSongs.length - 1 ? goNext : null,
                          ),
                        ),

                        // ⭐ COPY SHARE (CENTER) — moved a bit lower
                        Positioned(
  bottom: 0,
  left: 0,
  right: 0,
  child: Center(
    child: _HeaderActions(song: song),
  ),
),

                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Lyrics content
          SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
    child: buildLyricsView(context, song.lyrics),
  ),
),
        ],
      ),
    );
  }

  // --- Helpers --------------------------------------------------

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
}

/// Holds the right-side strings
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

/// Right-side row: aligns left small column with right text like SDAH
class _RightRow extends StatelessWidget {
  final String? left;
  final String? right;

  const _RightRow({super.key, this.left, this.right});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String clean(String? v) {
      final t = (v ?? '').trim();
      return t.isEmpty ? '—' : t;
    }

    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
          letterSpacing: 0.1,
          color: scheme.onSurface.withOpacity(0.70),
          height: 1.05,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ✅ Meter/tune column (give it enough room + scale down if needed)
        SizedBox(
          width: 30, // was 25 (too small)
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(clean(left), style: style),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // ✅ Author/by column (scale down instead of ellipsis)
        SizedBox(
          width: 70, // was 60 (too small for names)
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(clean(right), style: style),
            ),
          ),
        ),
      ],
    );
  }
}


/// ✅ Icons row in the middle (Favorites, Copy, Share)
class _HeaderActions extends StatelessWidget {
  final Song song;
  const _HeaderActions({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final greener = Color.lerp(scheme.primary, Colors.green, 0.35)!;

    Widget pill({required Widget child, required VoidCallback onTap}) {
      return Material(
        color: greener.withOpacity(0.1),
        borderRadius: BorderRadius.circular(600),
        child: InkWell(
          borderRadius: BorderRadius.circular(600),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: IconTheme(
              data: IconThemeData(color: greener, size: 15), // ✅ keep size
              child: child,
            ),
          ),
        ),
      );
    }

    String shareText(Song s) {
      final header = '${s.number}. ${s.title}';
      final lyrics = s.lyrics.trim().isEmpty ? 'Lyrics not added yet.' : s.lyrics.trim();
      return '$header\n\n$lyrics\n\n— SDA Lusoga Hymnal';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 35), // ✅ lowers the icons row
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: favorites,
            builder: (_, __) {
              final isFav = favorites.isFav(song.number);

              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: isFav ? 1.12 : 1.0),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: pill(
                  onTap: () => favorites.toggle(song.number),
                  child: Icon(isFav ? Icons.favorite : Icons.favorite_border),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          pill(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: shareText(song)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied!')),
                );
              }
            },
            child: const Icon(Icons.copy),
          ),
          const SizedBox(width: 10),
          pill(
            onTap: () => Share.share(shareText(song)),
            child: const Icon(Icons.share),
          ),
        ],
      ),
    );
  }
}


/// ----------------------
/// ✅ PinnedHeaderDelegate
/// ----------------------
class PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  PinnedHeaderDelegate({
    required this.height,
    required this.child,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant PinnedHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
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
  final blocks = parseLyricsBlocks(raw);

  if (raw.trim().isEmpty) {
    return const Text('Lyrics not added yet.');
  }

  return AnimatedBuilder(
    animation: settings,
    builder: (_, __) {
      final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: settings.fontSize,
            height: 1.20,
            fontWeight: FontWeight.w500,
          );

      if (blocks.isEmpty) {
        return Text(raw, style: baseStyle);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in blocks) ...[
            if (b.isChorus) ...[
              // ✅ Chorus label (no container)
              Text(
                'Chorus',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),

              // ✅ Chorus text — slight emphasis only
              _StanzaView(
                text: b.text,
                style: baseStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else
              Text(b.text, style: baseStyle),

            const SizedBox(height: 20),
          ],
        ],
      );
    },
  );
}

class _StanzaView extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _StanzaView({
    required this.text,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = text.split('\n');

    if (lines.isEmpty) return Text(text, style: style);

    final firstLine = lines.first.trim();

    // Detect stanza number: "1." or "2)"
    final match = RegExp(r'^(\d+)[\.\)]\s*(.*)').firstMatch(firstLine);

    // Not a numbered stanza → normal text
    if (match == null) {
      return Text(text, style: style);
    }

    final number = match.group(1)!;
    final firstText = match.group(2) ?? '';
    final rest = lines.skip(1).join('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ✅ Centered stanza number
        Center(
          child: Text(
            number,
            style: style?.copyWith(
              fontSize: (style?.fontSize ?? 18) - 2,
              fontWeight: FontWeight.w700,
              color: scheme.primary.withOpacity(0.85),
            ),
          ),
        ),
        const SizedBox(height: 6),

        Text(
          [
            if (firstText.isNotEmpty) firstText,
            if (rest.isNotEmpty) rest,
          ].join('\n'),
          style: style?.copyWith(
            height: settings.lineHeight * 0.9,
          ),
        ),
      ],
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
    return SafeArea(
      child: AnimatedBuilder(
        animation: settings,
        builder: (_, __) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reading settings', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  Text('Font size: ${settings.fontSize.toStringAsFixed(0)}'),
                  Slider(
                    value: settings.fontSize,
                    min: 14,
                    max: 28,
                    divisions: 14,
                    onChanged: settings.setFontSize,
                  ),
                  const SizedBox(height: 8),
                  Text('Line spacing: ${settings.lineHeight.toStringAsFixed(2)}'),
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
                      ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (set) => settings.setThemeMode(set.first),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Preview: Katonda ye mulungi. (This is a sample preview.)',
                        style: TextStyle(fontSize: settings.fontSize, height: settings.lineHeight),
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
                borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.25)),
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
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
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


 
