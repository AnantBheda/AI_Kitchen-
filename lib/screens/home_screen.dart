import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:ai_kitchen/providers/recipe_provider.dart';
import 'package:ai_kitchen/widgets/recipe_card.dart';
import 'package:ai_kitchen/widgets/ingredient_input.dart';
import 'package:ai_kitchen/widgets/fancy_button.dart';
import 'package:lottie/lottie.dart';
import 'package:ai_kitchen/widgets/recipe_options.dart';
import 'package:ai_kitchen/models/recipe.dart';
import 'package:ai_kitchen/screens/favorites_screen.dart';

// Enum to manage UI state for input mode
enum InputMode { none, addIngredients, findIngredients }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _ingredientController = TextEditingController();
  final List<String> _ingredients = [];
  bool _isListening = false;
  String _selectedLanguage = 'en-IN';
  late AnimationController _loadingController;
  late AnimationController _micController;
  final TextEditingController _dishNameController = TextEditingController();
  List<Ingredient>? _dishIngredients;
  bool _isFetchingDishIngredients = false;

  // State variable for the current input mode
  InputMode _currentMode = InputMode.none;

  final Map<String, String> _supportedLanguages = {
    'en-IN': 'English (India)',
    'hi-IN': 'हिंदी (Hindi)',
    'ta-IN': 'தமிழ் (Tamil)',
    'te-IN': 'తెలుగు (Telugu)',
    'mr-IN': 'मराठी (Marathi)',
    'bn-IN': 'বাংলা (Bengali)',
    'gu-IN': 'ગુજરાતી (Gujarati)',
    'kn-IN': 'ಕನ್ನಡ (Kannada)',
    'ml-IN': 'മലയാളം (Malayalam)',
    'pa-IN': 'ਪੰਜਾਬੀ (Punjabi)',
    'ur-IN': 'اردو (Urdu)',
    'or-IN': 'ଓଡ଼ିଆ (Odia)',
    'as-IN': 'অসমীয়া (Assamese)',
  };

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _micController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  Future<void> _initializeSpeech() async {
    await _speech.initialize(
      onError: (error) => _showSnackBar(error.errorMsg, isError: true),
      onStatus: (status) => _handleSpeechStatus(status),
    );
  }

  void _handleSpeechStatus(String status) {
    if (status == 'listening') {
      _showSnackBar(
          'Listening in ${_supportedLanguages[_selectedLanguage]}...');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  Future<void> _startListening() async {
    if (!_isListening) {
      final available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _micController.forward();
        await _speech.listen(
          onResult: (result) {
            if (result.finalResult) {
              setState(() {
                _ingredients.add(result.recognizedWords);
                _isListening = false;
              });
              _micController.reverse();
            }
          },
          localeId: _selectedLanguage,
          cancelOnError: true,
          partialResults: false,
        );
      }
    } else {
      setState(() => _isListening = false);
      _micController.reverse();
      await _speech.stop();
    }
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      setState(() => _isListening = false);
      _micController.reverse();
      await _speech.stop();
      print("Speech recognition stopped.");
    }
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.all(8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Language',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _supportedLanguages.length,
                  itemBuilder: (context, index) {
                    final language =
                        _supportedLanguages.entries.elementAt(index);
                    return ListTile(
                      title: Text(language.value),
                      trailing: _selectedLanguage == language.key
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () {
                        setState(() => _selectedLanguage = language.key);
                        Navigator.pop(context);
                        _showSnackBar('Selected: ${language.value}');
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        _loadingController.forward();
        await Provider.of<RecipeProvider>(context, listen: false)
            .getRecipeFromImage(File(image.path));
        _loadingController.reset();
      }
    } catch (e) {
      _loadingController.reset();
      _showSnackBar('Error picking image: $e', isError: true);
    }
  }

  // Modified method to generate recipes (only relevant in addIngredients mode)
  Future<void> _generateRecipes() async {
    if (_ingredients.isEmpty) {
      _showSnackBar('Please add some ingredients first.', isError: true);
      return;
    }
    // Clear dish ingredients if switching from that mode's result
    setState(() {
      _dishIngredients = null;
    });
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    await recipeProvider.getRecipeFromIngredients(_ingredients);
  }

  // Modified method to get ingredients (only relevant in findIngredients mode)
  Future<void> _getIngredientsForDish() async {
    final dishName = _dishNameController.text.trim();
    if (dishName.isEmpty) {
      _showSnackBar('Please enter a dish name.', isError: true);
      return;
    }
    setState(() {
      _isFetchingDishIngredients = true;
      _dishIngredients = null; // Clear previous results
    });
    // Clear recipe results if switching from that mode's result
    Provider.of<RecipeProvider>(context, listen: false).clearRecipes();
    try {
      final ingredients =
          await Provider.of<RecipeProvider>(context, listen: false)
              .getIngredientsForDish(dishName);
      setState(() {
        _dishIngredients = ingredients;
      });
    } catch (e) {
      _showSnackBar('Could not fetch ingredients: $e', isError: true);
    } finally {
      setState(() {
        _isFetchingDishIngredients = false;
      });
    }
  }

  // Method to remove an ingredient from the list
  void _removeIngredient(String ingredient) {
    setState(() {
      _ingredients.remove(ingredient);
    });
  }

  // Method to reset the input mode
  void _resetMode() {
    setState(() {
      _currentMode = InputMode.none;
      _ingredients.clear();
      _ingredientController.clear();
      _dishNameController.clear();
      _dishIngredients = null;
      // Clear any recipe results as well
      Provider.of<RecipeProvider>(context, listen: false).clearRecipes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    // Determine loading state
    final bool isLoading =
        recipeProvider.isLoading || _isFetchingDishIngredients;

    // Determine if results (recipes or dish ingredients) are available
    final bool hasRecipeResults = _currentMode == InputMode.addIngredients &&
        recipeProvider.selectedRecipes != null &&
        recipeProvider.selectedRecipes!.isNotEmpty;
    final bool hasDishIngredientResults =
        _currentMode == InputMode.findIngredients &&
            _dishIngredients != null &&
            _dishIngredients!.isNotEmpty;

    // For filtered recipes
    List<Recipe> filteredRecipes = recipeProvider.selectedRecipes ?? [];
    
    return Scaffold(
      backgroundColor: colorScheme.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 56,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            tooltip: 'Favorites',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FavoritesScreen()),
              );
            },
          ),
        ],
      ),
      // Wrap body in PopScope to handle back button presses
      body: PopScope(
        // canPop is false if a mode is selected, meaning we intercept the pop
        canPop: _currentMode == InputMode.none,
        // onPopInvoked is called when a pop is attempted (e.g., system back button)
        onPopInvoked: (didPop) {
          // If pop was prevented (didPop is false), reset the mode
          if (!didPop && _currentMode != InputMode.none) {
            print("[HomeScreen] Intercepted back press, resetting mode.");
            _resetMode();
          }
        },
        child: Stack(
          children: [
            // Main scrollable content
            CustomScrollView(
              slivers: [
                // Removed duplicate title
                SliverAppBar(
                  floating: true,
                  snap: true,
                  actions: [
    
                    // Reset button only shown when a mode is selected
                    if (_currentMode != InputMode.none)
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Start Over',
                        onPressed: _resetMode,
                      ),
                  ],
                ),

                // == Mode Selection UI ==
                if (_currentMode == InputMode.none)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 40.0, horizontal: 24.0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Container(
                          margin: const EdgeInsets.only(bottom: 30),
                          child: Column(
                            children: [
                              Text(
                                'AI Kitchen',
                                style: Theme.of(context)
                                    .textTheme
                                    .displayMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your Smart Cooking Assistant',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: colorScheme.secondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'How do you want to find recipes?',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 50),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            color: colorScheme.primary,
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: colorScheme.onPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              minimumSize: Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            onPressed: () => setState(
                                () => _currentMode = InputMode.addIngredients),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline,
                                    color: colorScheme.onPrimary),
                                const SizedBox(width: 12),
                                const Text('Add Ingredients I Have',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 30),
                          child: Text("OR",
                              style: TextStyle(
                                  color: colorScheme.secondary.withOpacity(0.7),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500)),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            color: colorScheme.secondaryContainer,
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: colorScheme.onSecondaryContainer,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              minimumSize: Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            onPressed: () => setState(
                                () => _currentMode = InputMode.findIngredients),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search,
                                    color: colorScheme.onSecondaryContainer),
                                const SizedBox(width: 12),
                                const Text('Find Ingredients for a Dish',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),

                // == Add Ingredients Mode UI ==
                if (_currentMode == InputMode.addIngredients) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 8.0),
                      child: Text(
                        'Add Your Ingredients:',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: IngredientInput(
                              controller: _ingredientController,
                              onSubmitted: (value) {
                                if (value.isNotEmpty &&
                                    !_ingredients.contains(value.trim())) {
                                  setState(
                                      () => _ingredients.add(value.trim()));
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ScaleTransition(
                            scale: Tween<double>(begin: 1, end: 1.2).animate(
                              CurvedAnimation(
                                parent: _micController,
                                curve: Curves.easeInOut,
                              ),
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color:
                                    _isListening ? colorScheme.primary : null,
                              ),
                              onPressed: _isListening
                                  ? _stopListening
                                  : _startListening,
                              tooltip: _isListening
                                  ? 'Stop listening'
                                  : 'Voice input',
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.camera_alt),
                            onPressed: _pickImage,
                            tooltip: 'Add ingredients from photo',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_ingredients.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                      sliver: SliverToBoxAdapter(
                        child: Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: _ingredients
                              .map((ingredient) => Chip(
                                    label: Text(ingredient),
                                    onDeleted: () =>
                                        _removeIngredient(ingredient),
                                    deleteIconColor:
                                        colorScheme.onSecondaryContainer,
                                    backgroundColor:
                                        colorScheme.secondaryContainer,
                                    labelStyle: TextStyle(
                                        color:
                                            colorScheme.onSecondaryContainer),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  if (_ingredients.isNotEmpty &&
                      !isLoading &&
                      !hasRecipeResults)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 20.0, horizontal: 60),
                      sliver: SliverToBoxAdapter(
                        child: FancyButton(
                          onPressed: _generateRecipes,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text('Generate Recipes',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ),
                    )
                ],

                // == Find Ingredients by Dish Name Mode UI ==
                if (_currentMode == InputMode.findIngredients) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 8.0),
                      child: Text(
                        'Find Ingredients By Dish:',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _dishNameController,
                            decoration: InputDecoration(
                              hintText: 'e.g., Butter Chicken, Masala Dosa',
                              filled: true,
                              fillColor:
                                  colorScheme.surfaceVariant.withOpacity(0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            onSubmitted: (_) => _getIngredientsForDish(),
                            textInputAction: TextInputAction.search,
                          ),
                          const SizedBox(height: 20),
                          if (!isLoading && !hasDishIngredientResults)
                            Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 44),
                                child: FancyButton(
                                  onPressed: _getIngredientsForDish,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12.0),
                                    child: Text('Find Ingredients',
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: colorScheme.onPrimary,
                                            fontWeight: FontWeight.w500)),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],

                // == Results Display Area ==

                if (hasDishIngredientResults)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ingredients for ${_dishNameController.text.trim()}:',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _dishIngredients!
                                    .map((ingredient) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4.0),
                                          child: Text(
                                              '• ${ingredient.quantity} ${ingredient.name}'),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (hasRecipeResults) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
                    sliver: SliverToBoxAdapter(
                      child: RecipeOptions(
                          recipes: recipeProvider.selectedRecipes!),
                    ),
                  ),
                ],
              ],
            ),

            // == Loading Indicator Overlay ==
            if (isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Lottie.asset(
                      'assets/animations/cooking.json',
                      controller: _loadingController,
                      height: 150,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _micController.dispose();
    _speech.stop();
    _ingredientController.dispose();
    _dishNameController.dispose();
    super.dispose();
  }
}
