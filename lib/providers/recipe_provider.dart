import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:ai_kitchen/models/recipe.dart';
import 'package:ai_kitchen/providers/ai_provider.dart';

class RecipeProvider with ChangeNotifier {
  List<Recipe> _recipes = [];
  List<Recipe>? _selectedRecipes;
  bool _isLoading = false;
  AIProvider? _aiProvider;
  Recipe? _currentRecipe;
  String? _error;
  List<Recipe> _favoriteRecipes = [];

  List<Recipe> get recipes => _recipes;
  List<Recipe>? get selectedRecipes => _selectedRecipes;
  bool get isLoading => _isLoading;
  Recipe? get currentRecipe => _currentRecipe;
  String? get error => _error;
  List<Recipe> get favoriteRecipes => _favoriteRecipes;

  RecipeProvider(this._aiProvider);

  void setAIProvider(AIProvider provider) {
    _aiProvider = provider;
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> getRecipeFromIngredients(List<String> ingredients) async {
    print(
        "[RecipeProvider] getRecipeFromIngredients called with: ${ingredients.join(', ')}");
    _setState(loading: true, error: null, recipes: null);
    try {
      print("[RecipeProvider] Calling AIProvider.generateRecipes...");
      final recipes = await _aiProvider!.generateRecipes(ingredients);
      print(
          "[RecipeProvider] Received ${recipes.length} recipes from AIProvider.");
      _recipes.addAll(recipes);
      _selectedRecipes = recipes;
      notifyListeners();
      setLoading(false);
    } catch (e) {
      print("[RecipeProvider] Error in getRecipeFromIngredients: $e");
      setLoading(false);
      _setState(error: e.toString());
    }
  }

  Future<void> getRecipeFromImage(File image) async {
    print("[RecipeProvider] getRecipeFromImage called.");
    _setState(loading: true, error: null, recipes: null);
    try {
      print("[RecipeProvider] Calling AIProvider.generateRecipeFromImage...");
      final recipes = await _aiProvider!.generateRecipeFromImage(image);
      print(
          "[RecipeProvider] Received ${recipes.length} recipes from AIProvider (image).");
      _recipes.addAll(recipes);
      _selectedRecipes = recipes;
      notifyListeners();
      setLoading(false);
    } catch (e) {
      print("[RecipeProvider] Error in getRecipeFromImage: $e");
      setLoading(false);
      _setState(error: e.toString());
    }
  }

  Future<List<Ingredient>> getIngredientsForDish(String dishName) async {
    print("[RecipeProvider] getIngredientsForDish called with: $dishName");
    _setState(loading: true, error: null, recipes: null);
    try {
      print("[RecipeProvider] Calling AIProvider.getIngredientsForDish...");
      final ingredients = await _aiProvider!.getIngredientsForDish(dishName);
      print(
          "[RecipeProvider] Received ${ingredients.length} ingredients from AIProvider.");
      _setState(loading: false);
      return ingredients;
    } catch (e) {
      print("[RecipeProvider] Error in getIngredientsForDish: $e");
      _setState(loading: false, error: e.toString());
      rethrow;
    }
  }

  void clearSelectedRecipes() {
    _selectedRecipes = null;
    notifyListeners();
  }

  void setCurrentRecipe(Recipe recipe) {
    _currentRecipe = recipe;
    notifyListeners();
  }

  void clearCurrentRecipe() {
    _currentRecipe = null;
    notifyListeners();
  }

  void clearRecipes() {
    print("[RecipeProvider] clearRecipes called.");
    _setState(recipes: null, error: null);
  }
  
  // Favorites management
  void addToFavorites(Recipe recipe) {
    if (!_isRecipeInFavorites(recipe)) {
      _favoriteRecipes.add(recipe);
      notifyListeners();
    }
  }
  
  void removeFromFavorites(Recipe recipe) {
    _favoriteRecipes.removeWhere((item) => item.id == recipe.id);
    notifyListeners();
  }
  
  bool isRecipeInFavorites(Recipe recipe) {
    return _isRecipeInFavorites(recipe);
  }
  
  bool _isRecipeInFavorites(Recipe recipe) {
    return _favoriteRecipes.any((item) => item.id == recipe.id);
  }
  
  // Filter recipes
  List<Recipe> filterRecipesByDifficulty(String difficulty) {
    return _selectedRecipes?.where((recipe) => recipe.difficulty == difficulty).toList() ?? [];
  }
  
  List<Recipe> filterRecipesByTag(String tag) {
    return _selectedRecipes?.where((recipe) => recipe.tags.contains(tag)).toList() ?? [];
  }
  
  List<Recipe> filterRecipesByTime(int maxTime) {
    return _selectedRecipes?.where((recipe) => 
      (recipe.preparationTime + recipe.cookingTime) <= maxTime).toList() ?? [];
  }

  void _setState({
    bool? loading,
    String? error,
    List<Recipe>? recipes,
  }) {
    print(
        "[RecipeProvider] _setState called - loading: $loading, error: $error, recipes updated: ${recipes != null}");
    _isLoading = loading ?? _isLoading;
    _error = error;
    if (recipes != null || error != null || loading == false) {
      _selectedRecipes = recipes;
    } else if (loading == true) {
      print("[RecipeProvider] Clearing recipes on loading start.");
      _selectedRecipes = null;
    }
    notifyListeners();
    print(
        "[RecipeProvider] State update complete. isLoading: $_isLoading, hasError: ${_error != null}, recipesCount: ${_selectedRecipes?.length ?? 0}");
  }
}
