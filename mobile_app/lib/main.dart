import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'screens/auth/auth_screens.dart';
import 'screens/home/app_shell.dart';
import 'services/processing_screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Audio2TextApp());
}

class Audio2TextApp extends StatelessWidget {
  const Audio2TextApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Audio2Text AI',
      theme: AppTheme.dark,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/app': (context) => const AppShell(),

        AuthScreens.onboarding: (context) => const OnboardingScreen(),
        AuthScreens.login: (context) => const LoginScreen(),
        AuthScreens.register: (context) => const RegisterScreen(),
        AuthScreens.forgot: (context) => const ForgotPasswordScreen(),

        ProcessingScreens.upload: (context) => const UploadAudioScreen(),
        ProcessingScreens.processing: (context) => const ProcessingScreen(),
        ProcessingScreens.result: (context) =>
            const TranscriptionResultScreen(),
      },
    );
  }
}
