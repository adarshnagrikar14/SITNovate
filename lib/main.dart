import 'package:flutter/material.dart';
import 'package:sybot/core/routes/routes.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sybot/core/utils/system_chrome_utils.dart';
import 'package:sybot/core/di/injection_container.dart' as di;
import 'package:sybot/core/services/assistant_trigger_service.dart';
import 'package:sybot/core/utils/global_context.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChromeUtils.setSystemUIOverlayStyle();
  SystemChromeUtils.setPreferredOrientations();
  await di.init();
  await AssistantTriggerService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // return MultiBlocProvider(
    //   providers: [
    //     // BlocProvider(create: (_) => di.sl<ChatCubit>()),
    //     // Add other BlocProviders here
    //   ],
    //   child: MaterialApp(
    //     title: 'SyBot',
    //     theme: ThemeData(
    //       colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    //       useMaterial3: true,
    //     ),
    //     initialRoute: AppRoutes.splash,
    //     routes: AppRoutes.routes,
    //   ),
    // );
    return MaterialApp(
      navigatorKey: GlobalContext.navigatorKey,
      title: 'SyBot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
        appBarTheme: AppBarTheme(
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
      debugShowCheckedModeBanner: false,
    );
  }
}
