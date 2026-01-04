/// Dino Browser - Main Entry Point
/// 
/// Initializes Firebase and Provider, sets up theme and routing
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'config/theme.dart';
import 'providers/browser_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/browser_screen.dart';
import 'screens/time_travel_history.dart';
import 'screens/extension_store.dart';
import 'screens/roar_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/fossil_pages_screen.dart';
import 'screens/ai_agent_screen.dart';
import 'screens/raptor_mode_screen.dart';
import 'screens/bookmarks_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/setup_profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Set system UI style (not available on web)
  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: DinoColors.darkBg,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    
    // Set preferred orientations (not available on web)
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  }
  
  runApp(const DinoBrowserApp());
}

class DinoBrowserApp extends StatefulWidget {
  const DinoBrowserApp({super.key});

  @override
  State<DinoBrowserApp> createState() => _DinoBrowserAppState();
}

class _DinoBrowserAppState extends State<DinoBrowserApp> with WidgetsBindingObserver {
  BrowserProvider? _browserProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Save session when app goes to background or is closing
      _browserProvider?.saveSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BrowserProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Builder(
        builder: (context) {
          // Capture browser provider reference for lifecycle management
          _browserProvider = context.read<BrowserProvider>();
          
          return MaterialApp(
            title: 'DINO',
            debugShowCheckedModeBanner: false,
            theme: DinoTheme.darkTheme,
            home: const SplashScreen(),
            routes: {
              '/browser': (context) => const BrowserScreen(),
              '/history': (context) => const TimeTravelHistoryScreen(),
              '/extensions': (context) => const ExtensionStoreScreen(),
              '/roar': (context) => const RoarScreen(),
              '/auth': (context) => const AuthScreen(),
              '/fossils': (context) => const FossilPagesScreen(),
              '/ai': (context) => const AiAgentScreen(),
              '/raptor': (context) => const RaptorModeScreen(),
              '/bookmarks': (context) => const BookmarksScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/setup-profile': (context) => const SetupProfileScreen(),
            },
          );
        },
      ),
    );
  }
}
