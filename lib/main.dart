// lib/main.dart — MainScreen + нижняя капсула (плавающая панель)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:layn_app/providers/theme_provider.dart';
import 'package:layn_app/screens/home_screen.dart';
import 'package:layn_app/screens/search_screen.dart';
import 'package:layn_app/screens/profile_screen.dart';
import 'package:layn_app/screens/upload_screen.dart';
import 'package:layn_app/widgets/update_dialog.dart';
import 'package:layn_app/services/update_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final isDark = themeProvider.isDarkMode;
          
          // ✅ Делаем навигационную панель прозрачной и отключаем принудительный контраст Android
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarContrastEnforced: false, // Отключает затемнение на Android 10+
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ));

          return MaterialApp(
            title: 'Layn',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.light,
              primaryColor: const Color(0xFF065FD4),
              scaffoldBackgroundColor: Colors.white,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF065FD4),
                brightness: Brightness.light,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                elevation: 0,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primaryColor: const Color(0xFF065FD4),
              scaffoldBackgroundColor: const Color(0xFF0F0F0F),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF065FD4),
                brightness: Brightness.dark,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF0F0F0F),
                elevation: 0,
              ),
            ),
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _navVisible = true;
  final double _navBarHeight = 62;
  final UpdateService _updateService = UpdateService();

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    UploadScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkUpdate() async {
    final result = await _updateService.checkForUpdate();
    if (result != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: !result['force'],
        builder: (_) => UpdateDialog(
          version: result['version'] ?? '',
          changelog: result['changelog'] ?? '',
          force: result['force'] ?? false,
        ),
      );
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    setState(() {});
  }

  void _onNavChanged(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    const tabMargin = 24.0;
    final bottomMargin = 16.0 + bottomInset;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.only(
              bottom: _navVisible ? bottomMargin + _navBarHeight + 8 : 0,
            ),
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
          Positioned(
            left: tabMargin,
            right: tabMargin,
            bottom: bottomMargin,
            child: _buildFloatingNavBar(screenWidth, tabMargin),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar(double screenWidth, double tabMargin) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabWidth = (screenWidth - tabMargin * 2) / _screens.length;

    return Container(
      height: _navBarHeight,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xBB1C1814)
            : const Color(0xDDEEEDE8),
        borderRadius: BorderRadius.circular(31),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black12,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(31),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Row(
            children: [
              _navItem(0, Icons.home_outlined, Icons.home, 'Главная', tabWidth),
              _navItem(1, Icons.search_outlined, Icons.search, 'Поиск', tabWidth),
              _navItem(2, Icons.add_circle_outline, Icons.add_circle, 'Загрузить', tabWidth),
              _navItem(3, Icons.person_outline, Icons.person, 'Профиль', tabWidth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label, double width) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isSelected
        ? const Color(0xFF065FD4)
        : isDark
            ? Colors.white54
            : Colors.black54;

    return GestureDetector(
      onTap: () => _onNavChanged(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
