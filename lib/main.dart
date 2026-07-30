import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/ad_service.dart';
import 'services/update_service.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const LaynApp());
}

class LaynApp extends StatefulWidget {
  const LaynApp({super.key});

  @override
  State<LaynApp> createState() => _LaynAppState();
}

class _LaynAppState extends State<LaynApp> {
  bool _ready = false;
  late final ApiService _api;
  late final AuthProvider _auth;

  static const _primaryColor = Color(0xFF065FD4);
  static const _bgLight = Colors.white;
  static const _bgDark = Color(0xFF0F0F0F);

  ThemeData get _lightTheme => ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: _primaryColor,
        useMaterial3: true,
        scaffoldBackgroundColor: _bgLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: _bgLight,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      );

  ThemeData get _darkTheme => ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF3EA6FF),
        useMaterial3: true,
        scaffoldBackgroundColor: _bgDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: _bgDark,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      );

  @override
  void initState() {
    super.initState();
    // Прозрачная системная навигация — наш градиент виден до самого низа
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
    _api = ApiService.instance;
    _auth = AuthProvider(_api);
    _initAsync();
  }

  Future<void> _initAsync() async {
    // Pre-fetch home data while showing splash screen
    await Future.wait([
      _auth.init(),
      _prefetchHomeData(),
    ]);
    if (!mounted) return;
    setState(() => _ready = true);

    // Lazy-init ads after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService().init();
    });
  }

  /// Pre-fetch data into ApiService cache so HomeScreen loads instantly
  Future<void> _prefetchHomeData() async {
    try {
      // Fire these into cache — HomeScreen will use same cache
      await Future.wait([
        _api.home(page: 1, category: null),
        _api.categories(),
      ]);
    } catch (_) {
      // Pre-fetch failures are OK, HomeScreen will fetch again
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        title: 'Layn',
        debugShowCheckedModeBanner: false,
        theme: _lightTheme,
        home: const _SplashScreen(),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: _auth),
        Provider.value(value: _api),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'Layn',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          home: const MainScreen(),
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F0F0F)
          : Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_fill,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Layn',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _idx = 0;
  final ValueNotifier<bool> _uiVisible = ValueNotifier(true);

  final _screens = [
    HomeScreen(),
    SearchScreen(),
    ProfileScreen(),
  ];

  // Warm dark nav bar colors (matching screenshot)
  static const _navBgTop = Color(0xFF28221E);
  static const _navBgBottom = Color(0xFF181412);
  static const _navActiveColor = Color(0xFFE6D3BA);  // warm beige active
  static const _navInactiveColor = Color(0xFF8A7C6C); // muted warm inactive
  static const _navBarHeight = 72.0;

  @override
  void initState() {
    super.initState();
    // Set up HomeScreen with scroll visibility
    _screens[0] = HomeScreen(uiVisible: _uiVisible);
    // Check for app updates on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final totalNavH = _navBarHeight + bottomInset;

    return Scaffold(
      body: ValueListenableBuilder<bool>(
        valueListenable: _uiVisible,
        builder: (context, visible, _) => Stack(
          children: [
            // Body content — bottom padding animates to fill freed space
            AnimatedPadding(
              padding: EdgeInsets.only(bottom: visible ? totalNavH : 0),
              duration: const Duration(milliseconds: 200),
              child: IndexedStack(
                index: _idx,
                children: _screens,
              ),
            ),
            // Navigation bar — кастомное, как на скриншоте
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                offset: Offset(0, visible ? 0 : 1),
                duration: const Duration(milliseconds: 200),
                child: _buildNavBar(totalNavH),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Custom bottom nav bar — warm dark gradient, как на скриншоте
  Widget _buildNavBar(double totalHeight) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: totalHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [_navBgTop, _navBgBottom]
              : [Colors.white, Colors.grey.shade100],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _navItem(0, Icons.home_outlined, Icons.home, 'Главная'),
            _navItem(1, Icons.search, Icons.search, 'Поиск'),
            _navItem(2, Icons.person_outline, Icons.person, 'Профиль'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData selectedIcon, String label) {
    final selected = _idx == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? _navActiveColor : Colors.black;
    final inactiveColor = isDark ? _navInactiveColor : Colors.grey.shade500;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (index != _idx) _uiVisible.value = true;
          setState(() => _idx = index);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            Icon(
              selected ? selectedIcon : icon,
              color: selected ? activeColor : inactiveColor,
              size: 25,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? activeColor : inactiveColor,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
