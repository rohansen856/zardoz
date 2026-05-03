import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';
import 'screens/design_detail_screen.dart';
import 'screens/projection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = AuthService();
  await authService.restoreSession();

  runApp(
    ChangeNotifierProvider.value(
      value: authService,
      child: const ZardozApp(),
    ),
  );
}

class ZardozApp extends StatelessWidget {
  const ZardozApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zardoz Embroidery',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeShell(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/design') {
          final designId = settings.arguments as int;
          return MaterialPageRoute(
            builder: (_) => DesignDetailScreen(designId: designId),
          );
        }
        if (settings.name == '/project') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => ProjectionScreen(
              imageUrl: args['imageUrl'] as String,
              title: args['title'] as String,
            ),
          );
        }
        return null;
      },
    );
  }
}
