import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/update_service.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LaynApp());
}

class LaynApp extends StatelessWidget {
  const LaynApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => ApiService()),
        ChangeNotifierProxyProvider<ApiService, AuthProvider>(
          create: (_) => AuthProvider(api: ApiService()),
          update: (_, api, prev) => prev ?? AuthProvider(api: api),
        ),
      ],
      child: MaterialApp(
        title: 'Layn',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F0F0F),
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFFE53935),
            surface: const Color(0xFF1A1A1A),
          ),
        ),
        home: const AppRoot(),
      ),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});
  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try { await context.read<AuthProvider>().init(); }
      catch (e, stack) { debugPrint('Error in init: $e\n$stack'); }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context);
    });
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}