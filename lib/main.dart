import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:ai_kitchen/screens/home_screen.dart';
import 'package:ai_kitchen/providers/recipe_provider.dart';
import 'package:ai_kitchen/providers/ai_provider.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const AIKitchenApp());
}

class AIKitchenApp extends StatelessWidget {
  const AIKitchenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AIProvider()),
        ChangeNotifierProxyProvider<AIProvider, RecipeProvider>(
          create: (context) => RecipeProvider(context.read<AIProvider>()),
          update: (context, aiProvider, previousRecipeProvider) =>
              RecipeProvider(aiProvider),
        ),
      ],
      child: MaterialApp(
        title: 'AI Kitchen',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
