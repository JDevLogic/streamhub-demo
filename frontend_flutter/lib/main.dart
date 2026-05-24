import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'navigation_observer.dart';
import 'providers/appearance_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/watch_history.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await WatchHistory.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: VoidTheme.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: AnimeStreamingApp()));
}

class AnimeStreamingApp extends ConsumerWidget {
  const AnimeStreamingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final baseTextTheme = GoogleFonts.soraTextTheme(ThemeData.dark().textTheme);
    final baseBg = appearance.isAmoled ? Colors.black : VoidTheme.bg;
    final surface =
        appearance.isAmoled ? const Color(0xFF050509) : VoidTheme.surface;
    final card = appearance.isAmoled ? const Color(0xFF090912) : VoidTheme.card;
    final transitions = appearance.reduceAnimations
        ? const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: _NoPageTransitionsBuilder(),
              TargetPlatform.iOS: _NoPageTransitionsBuilder(),
              TargetPlatform.windows: _NoPageTransitionsBuilder(),
            },
          )
        : const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: ZoomPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            },
          );

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: baseBg,
      systemNavigationBarIconBrightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StreamHub',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: baseBg,
        appBarTheme: AppBarTheme(
          backgroundColor: baseBg,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardColor: card,
        colorScheme: ColorScheme.dark(
          primary: VoidTheme.primary,
          secondary: VoidTheme.cyan,
          surface: surface,
        ),
        textTheme: baseTextTheme,
        dividerColor: VoidTheme.cardBorder,
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: VoidTheme.primary,
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        pageTransitionsTheme: transitions,
      ),
      builder: (context, child) {
        Widget result = child ?? const SizedBox.shrink();
        final media = MediaQuery.maybeOf(context);
        if (media != null && appearance.reduceAnimations) {
          result = MediaQuery(
            data: media.copyWith(disableAnimations: true),
            child: result,
          );
        }
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: result,
        );
      },
      navigatorObservers: [appRouteObserver],
      home: const _AuthGate(),
    );
  }
}

class _NoPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

/// Listens to [authProvider] and routes to the appropriate screen.
/// Uses [AnimatedSwitcher] for a smooth fade transition on state changes.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final reduceAnimations = ref.watch(
      appearanceProvider.select((state) => state.reduceAnimations),
    );

    final Widget child;
    if (auth.isInitializing) {
      child = const _SplashScreen(key: ValueKey('splash'));
    } else if (auth.isLoggedIn) {
      child = const MainNavigationScreen(key: ValueKey('main'));
    } else {
      child = const LoginScreen(key: ValueKey('login'));
    }

    return AnimatedSwitcher(
      duration:
          reduceAnimations ? Duration.zero : const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: child,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  VoidTheme.gradientPrimary.createShader(bounds),
              child: Text(
                'StreamHub',
                style: GoogleFonts.sora(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: VoidTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
