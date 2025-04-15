import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ai_kitchen/models/recipe.dart';

class AIProvider with ChangeNotifier {
  GenerativeModel? _model;
  final Random _random = Random();

  // --- System Prompts ---

  static const String _recipeSystemPrompt = """
You are an expert chef specializing in diverse world cuisines, with a particular focus on Indian regional variations (North Indian, South Indian, Bengali, Gujarati, Maharashtrian, Kerala, etc.).
Your task is to generate at least 5 creative and delicious recipes based *only* on the provided list of ingredients.
Prioritize Indian recipes if common Indian ingredients are present (like paneer, specific dals, Indian spices, etc.). Otherwise, suggest diverse international options (Italian, Mexican, Chinese, Thai etc.).
For each recipe, provide:
- id: A unique identifier (e.g., 'gen-recipe-1')
- title: An appealing name for the dish.
- description: A short, enticing description.
- ingredients: A list of ingredients needed, EACH with 'name' and 'quantity' (be specific, e.g., '1 cup chopped onions', '2 tsp cumin powder', 'to taste'). Include the provided ingredients and any essential additions (like oil, salt, basic spices if clearly implied and necessary).
- instructions: A list of clear, step-by-step cooking instructions.
- preparationTime: Estimated preparation time in minutes (integer).
- cookingTime: Estimated cooking time in minutes (integer).
- servings: Number of people the recipe serves (integer).
- difficulty: 'Easy', 'Medium', or 'Hard'.
- tags: A list of relevant tags (e.g., 'Indian', 'Vegetarian', 'Quick', 'Spicy', 'South Indian', 'Dinner').
- imageUrl: A URL to an image that represents this dish. Generate a descriptive prompt for an image of this dish and use it to create a URL in this format: "https://source.unsplash.com/featured/?{cuisine},{dish name},{main ingredients}". For example, "https://source.unsplash.com/featured/?indian+cuisine,butter+chicken,curry+cream+tomato" for a butter chicken curry. Ensure spaces are replaced with + signs and the URL is properly encoded. Make the image query specific and detailed to get the most relevant image.

Format the output as a VALID JSON list containing the recipe objects. Example structure for one recipe:
{
  "id": "gen-recipe-1",
  "title": "Spicy Paneer Stir-fry",
  "description": "A quick and flavorful stir-fry...",
  "ingredients": [
    {"name": "Paneer", "quantity": "200g cubed"},
    {"name": "Bell Pepper", "quantity": "1 chopped"}
  ],
  "instructions": [
    "Heat oil in a pan.",
    "Sauté onions until translucent."
  ],
  "preparationTime": 10,
  "cookingTime": 15,
  "servings": 2,
  "difficulty": "Easy",
  "tags": ["Indian", "Vegetarian", "Quick"],
  "imageUrl": "https://source.unsplash.com/featured/?indian+food,paneer+stir+fry"
}
Ensure the entire output is JUST the JSON list, nothing else.
""";

  static const String _ingredientListSystemPrompt = """
You are a helpful kitchen assistant. Given the name of a dish, list the typical ingredients required to make it, including estimated quantities.
Focus on common preparations of the dish.
Format the output as a VALID JSON list of ingredient objects, where each object has 'name' and 'quantity'. Example:
[
  {"name": "Chicken", "quantity": "500g"},
  {"name": "Butter", "quantity": "100g"},
  {"name": "Tomato Puree", "quantity": "1 cup"}
]
Ensure the entire output is JUST the JSON list, nothing else.
""";

  static const String _imageIngredientSystemPrompt = """
You are an expert at identifying food ingredients from images.
Analyze the provided image and list all the recognizable food items or ingredients visible.
Format the output as a simple VALID JSON list of strings. Example:
["tomatoes", "onions", "green chilies", "paneer"]
Ensure the entire output is JUST the JSON list, nothing else.
""";

  AIProvider() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      print("[AIProvider] Initializing Gemini model...");
      _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);
      print(
          "[AIProvider] Gemini model initialized with gemini-1.5-flash-latest.");
    } else {
      print(
          '[AIProvider] Warning: GEMINI_API_KEY not found in .env. AI features will use mock data.');
    }
  }

  // --- Public Methods ---

  Future<List<Recipe>> generateRecipes(List<String> ingredients) async {
    print(
        "[AIProvider] generateRecipes called with: ${ingredients.join(', ')}");
    if (_model == null) {
      print('[AIProvider] Using mock recipe generation (No API Key).');
      return _mockGenerateRecipes(ingredients);
    }
    if (ingredients.isEmpty) {
      print("[AIProvider] generateRecipes: No ingredients provided.");
      return [];
    }

    try {
      final prompt = [
        Content.text(_recipeSystemPrompt),
        Content.text(
            'Generate recipes using these ingredients: ${ingredients.join(', ')}')
      ];
      print("[AIProvider] Sending recipe generation prompt to Gemini...");

      final response = await _model!.generateContent(prompt);
      final text = response.text;

      print(
          "[AIProvider] Gemini recipe raw response received: ${text?.substring(0, min(text?.length ?? 0, 200))}..."); // Log more

      if (text == null || text.isEmpty) {
        print(
            "[AIProvider] Error: Received empty response from AI model for recipes.");
        throw Exception('Received empty response from AI model.');
      }
      print("[AIProvider] Parsing recipe JSON...");
      return _parseRecipeJson(text);
    } catch (e) {
      print('[AIProvider] Error generating recipes via Gemini: $e');
      // Optionally, fallback to mock data on error?
      // print("[AIProvider] Falling back to mock recipes due to error.");
      // return _mockGenerateRecipes(ingredients);
      throw Exception('Failed to generate recipes. $e');
    }
  }

  Future<List<Recipe>> generateRecipeFromImage(File image) async {
    print("[AIProvider] generateRecipeFromImage called.");
    if (_model == null) {
      print(
          '[AIProvider] Using mock recipe generation from image (No API Key).');
      return _mockGenerateRecipes(['mock ingredient from image']);
    }

    List<String> identifiedIngredients = [];
    try {
      // 1. Identify ingredients from image
      print("[AIProvider] Identifying ingredients from image...");
      final imageBytes = await image.readAsBytes();
      final imagePart = DataPart('image/jpeg', imageBytes);
      final prompt = [
        Content.text(_imageIngredientSystemPrompt),
        Content.multi([imagePart])
      ];
      print("[AIProvider] Sending image analysis prompt to Gemini...");

      final response = await _model!.generateContent(prompt);
      final text = response.text;
      print(
          "[AIProvider] Gemini image ingredients raw response received: ${text?.substring(0, min(text?.length ?? 0, 200))}...");

      if (text == null || text.isEmpty) {
        print(
            "[AIProvider] Error: Received empty response from AI model for image analysis.");
        throw Exception(
            'Received empty response from AI model during image analysis.');
      }

      // Parse ingredients
      print("[AIProvider] Parsing image ingredients JSON...");
      try {
        final List<dynamic> decodedList = jsonDecode(text);
        identifiedIngredients =
            decodedList.map((item) => item.toString()).toList();
        print(
            "[AIProvider] Ingredients identified from image (JSON parse): $identifiedIngredients");
      } catch (e) {
        print(
            '[AIProvider] Error parsing ingredient list JSON from image response: $e');
        identifiedIngredients = text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        print(
            '[AIProvider] Parsed ingredients using fallback split method: $identifiedIngredients');
        if (identifiedIngredients.isEmpty) {
          print(
              "[AIProvider] Error: Could not parse ingredients from image analysis response using fallback.");
          throw Exception(
              'Could not parse ingredients from image analysis response.');
        }
      }

      if (identifiedIngredients.isEmpty) {
        print(
            "[AIProvider] Error: No ingredients identified from the image after parsing.");
        throw Exception('No ingredients identified from the image.');
      }

      // 2. Generate recipes using identified ingredients
      print(
          '[AIProvider] Generating recipes for identified ingredients: $identifiedIngredients');
      // IMPORTANT: Make sure this call returns the result
      return await generateRecipes(
          identifiedIngredients); // Calls the updated generateRecipes
    } catch (e) {
      print('[AIProvider] Error in generateRecipeFromImage: $e');
      // Optionally, fallback to mock data on error?
      // print("[AIProvider] Falling back to mock recipes due to image error.");
      // return _mockGenerateRecipes(identifiedIngredients.isNotEmpty ? identifiedIngredients : ['failed image parse']);
      throw Exception('Failed to generate recipe from image. $e');
    }
  }

  Future<List<Ingredient>> getIngredientsForDish(String dishName) async {
    print("[AIProvider] getIngredientsForDish called with: $dishName");
    if (_model == null) {
      print(
          '[AIProvider] Using mock ingredients lookup for: $dishName (No API Key).');
      return _mockDishIngredients[dishName.toLowerCase()] ?? [];
    }
    if (dishName.trim().isEmpty) {
      print("[AIProvider] getIngredientsForDish: No dish name provided.");
      return [];
    }

    try {
      final prompt = [
        Content.text(_ingredientListSystemPrompt),
        Content.text('List ingredients for: $dishName')
      ];
      print("[AIProvider] Sending ingredient lookup prompt to Gemini...");

      final response = await _model!.generateContent(prompt);
      final text = response.text;
      print(
          "[AIProvider] Gemini ingredient list raw response received: ${text?.substring(0, min(text?.length ?? 0, 200))}...");

      if (text == null || text.isEmpty) {
        print(
            "[AIProvider] Error: Received empty response from AI model for ingredients.");
        throw Exception('Received empty response from AI model.');
      }
      print("[AIProvider] Parsing ingredients JSON...");
      return _parseIngredientJson(text);
    } catch (e) {
      print('[AIProvider] Error fetching ingredients for dish via Gemini: $e');
      // Optionally, fallback?
      // print("[AIProvider] Falling back to mock ingredients due to error.");
      // return _mockDishIngredients[dishName.toLowerCase()] ?? [];
      throw Exception('Failed to fetch ingredients for dish. $e');
    }
  }

  // --- Helper Methods ---

  List<Recipe> _parseRecipeJson(String jsonString) {
    print("[AIProvider] _parseRecipeJson called.");
    try {
      // Clean the string: Remove potential markdown fences and trim whitespace
      String cleanedJson = jsonString.trim();
      if (cleanedJson.startsWith('```json')) {
        cleanedJson = cleanedJson.substring(7);
      }
      if (cleanedJson.startsWith('```')) {
        cleanedJson = cleanedJson.substring(3);
      }
      if (cleanedJson.endsWith('```')) {
        cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3);
      }
      cleanedJson = cleanedJson.trim();

      final List<dynamic> decodedList = jsonDecode(cleanedJson);
      return decodedList
          .map((item) {
            try {
              // Log the URLs being parsed
              final map = item as Map<String, dynamic>;
              print(
                  "[AIProvider] Parsing recipe item: title='${map['title']}'");
              return Recipe.fromMap(map);
            } catch (e) {
              print(
                  "[AIProvider] Error parsing individual recipe item: $item, Error: $e");
              return null; // Skip invalid items
            }
          })
          .whereType<Recipe>()
          .toList(); // Filter out nulls
    } catch (e) {
      print('Error decoding recipe JSON: $e');
      print(
          'Problematic JSON string snippet: ${jsonString.substring(0, min(jsonString.length, 200))}');
      return []; // Return empty list on top-level parse error
    }
  }

  List<Ingredient> _parseIngredientJson(String jsonString) {
    print("[AIProvider] _parseIngredientJson called.");
    try {
      // Clean the string: Remove potential markdown fences and trim whitespace
      String cleanedJson = jsonString.trim();
      if (cleanedJson.startsWith('```json')) {
        cleanedJson = cleanedJson.substring(7);
      }
      if (cleanedJson.startsWith('```')) {
        cleanedJson = cleanedJson.substring(3);
      }
      if (cleanedJson.endsWith('```')) {
        cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3);
      }
      cleanedJson = cleanedJson.trim();

      final List<dynamic> decodedList = jsonDecode(cleanedJson);
      return decodedList
          .map((item) {
            try {
              return Ingredient.fromMap(item as Map<String, dynamic>);
            } catch (e) {
              print(
                  "Error parsing individual ingredient item: $item, Error: $e");
              return null; // Skip invalid items
            }
          })
          .whereType<Ingredient>()
          .toList(); // Filter out nulls
    } catch (e) {
      print('Error decoding ingredient JSON: $e');
      print(
          'Problematic JSON string snippet: ${jsonString.substring(0, min(jsonString.length, 200))}');
      throw Exception('Failed to parse ingredient data from AI response.');
    }
  }

  // --- Mock Logic Implementation (Kept as fallback) ---

  final Map<String, List<Ingredient>> _mockDishIngredients = {
    'butter chicken': [
      Ingredient(name: 'Chicken', quantity: '500g'),
      Ingredient(name: 'Butter', quantity: '100g'),
      Ingredient(name: 'Tomato Puree', quantity: '1 cup'),
      Ingredient(name: 'Onion', quantity: '1 large'),
      Ingredient(name: 'Cashew Paste', quantity: '1/4 cup'),
      Ingredient(name: 'Cream', quantity: '1/2 cup'),
      Ingredient(name: 'Garam Masala', quantity: '1 tsp'),
      Ingredient(name: 'Ginger-Garlic Paste', quantity: '1 tbsp'),
    ],
    'masala dosa': [
      Ingredient(name: 'Dosa Rice', quantity: '1 cup'),
      Ingredient(name: 'Urad Dal', quantity: '1/4 cup'),
      Ingredient(name: 'Potato', quantity: '3 medium'),
      Ingredient(name: 'Onion', quantity: '1 medium'),
      Ingredient(name: 'Mustard Seeds', quantity: '1 tsp'),
      Ingredient(name: 'Turmeric Powder', quantity: '1/2 tsp'),
      Ingredient(name: 'Green Chilies', quantity: '2'),
      Ingredient(name: 'Curry Leaves', quantity: 'few'),
    ],
    'aloo gobi': [
      Ingredient(name: 'Potatoes', quantity: '2 large'),
      Ingredient(name: 'Cauliflower', quantity: '1 medium head'),
      Ingredient(name: 'Onion', quantity: '1 medium'),
      Ingredient(name: 'Tomato', quantity: '1 medium'),
      Ingredient(name: 'Ginger-Garlic Paste', quantity: '1 tsp'),
      Ingredient(name: 'Turmeric Powder', quantity: '1/2 tsp'),
      Ingredient(name: 'Cumin Seeds', quantity: '1 tsp'),
      Ingredient(name: 'Coriander Powder', quantity: '1 tsp'),
    ],
  };

  final List<Recipe> _mockRecipes = [
    Recipe(
      id: 'mock-indian-1',
      title: 'Aloo Gobi (Mock)',
      description: 'A simple North Indian dish.',
      ingredients: [
        Ingredient(name: 'Potatoes', quantity: '2 large'),
        Ingredient(name: 'Cauliflower', quantity: '1 medium head'),
      ],
      instructions: ['Cook potatoes.', 'Cook cauliflower.', 'Mix.'],
      preparationTime: 15,
      cookingTime: 25,
      servings: 3,
      difficulty: 'Easy',
      tags: ['Indian', 'Vegetarian', 'North Indian', 'Mock'],
      imageUrl: 'https://source.unsplash.com/featured/?indian+food,aloo+gobi',
    ),
    Recipe(
      id: 'mock-fusion-1',
      title: 'Indian Fusion Stir-fry (Mock)',
      description: 'A quick stir-fry.',
      ingredients: [Ingredient(name: 'Mixed Vegetables', quantity: '2 cups')],
      instructions: ['Stir-fry vegetables.'],
      preparationTime: 10,
      cookingTime: 15,
      servings: 2,
      difficulty: 'Easy',
      tags: ['Indian', 'Fusion', 'Vegetarian', 'Quick', 'Mock'],
      imageUrl: 'https://source.unsplash.com/featured/?indian+food,vegetable+stir+fry',
    ),
  ];

  List<Recipe> _mockGenerateRecipes(List<String> ingredients) {
    print('Mock generating recipes for: ${ingredients.join(', ')}');
    // Generate at least 5 mock recipes to match the updated system prompt
    final count = 5; // Ensure we generate at least 5 recipes
    List<Recipe> results = [];
    List<Recipe> availableRecipes = List.from(_mockRecipes);
    
    // Add all available mock recipes
    results.addAll(availableRecipes);
    
    // If we don't have enough recipes, generate additional ones with variations
    int additionalNeeded = count - results.length;
    
    // Add recipes using the input ingredients with variations
    if (ingredients.isNotEmpty) {
      // Add the basic recipe
      String mainIngredient = ingredients[0].replaceAll(' ', '+');
      results.add(Recipe(
        id: 'mock-custom-${_random.nextInt(1000)}',
        title: 'Mock Dish with ${ingredients[0]}',
        description: 'A simple mock recipe using your ingredients.',
        ingredients: ingredients
            .map((ing) => Ingredient(name: ing, quantity: 'some'))
            .toList(),
        instructions: [
          'Prepare ${ingredients.join(', ')}.',
          'Cook them somehow.',
          'Serve.'
        ],
        preparationTime: 5,
        cookingTime: 10,
        servings: 1,
        difficulty: 'Easy',
        tags: ['Mock', 'Custom'],
        imageUrl: 'https://source.unsplash.com/featured/?food,$mainIngredient',
      ));
      
      // Generate additional variations to reach the minimum count
      List<String> cuisineTypes = ['Indian', 'Italian', 'Chinese', 'Mexican', 'Thai', 'Mediterranean'];
      List<String> dishTypes = ['Curry', 'Stir-fry', 'Soup', 'Salad', 'Baked Dish', 'Grilled Specialty'];
      
      for (int i = 0; i < additionalNeeded - 1; i++) {
        String cuisine = cuisineTypes[_random.nextInt(cuisineTypes.length)];
        String dishType = dishTypes[_random.nextInt(dishTypes.length)];
        String ingredient = ingredients[_random.nextInt(ingredients.length)];
        String imageQuery = '${cuisine.toLowerCase()}+${dishType.toLowerCase()}+${ingredient.replaceAll(' ', '+')}'; 
        
        results.add(Recipe(
          id: 'mock-custom-${_random.nextInt(1000)}',
          title: '$cuisine $dishType with $ingredient',
          description: 'A delicious $cuisine style $dishType using your ingredients.',
          ingredients: ingredients
              .map((ing) => Ingredient(name: ing, quantity: '${_random.nextInt(3) + 1} units'))
              .toList(),
          instructions: [
            'Prepare ingredients in $cuisine style.',
            'Cook using $dishType technique.',
            'Add seasonings and spices.',
            'Serve hot with garnish.'
          ],
          preparationTime: 10 + _random.nextInt(20),
          cookingTime: 15 + _random.nextInt(30),
          servings: 2 + _random.nextInt(4),
          difficulty: ['Easy', 'Medium', 'Hard'][_random.nextInt(3)],
          tags: [cuisine, dishType, 'Mock', 'Custom'],
          imageUrl: 'https://source.unsplash.com/featured/?$imageQuery',
        ));
      }
    } else {
      // If no ingredients provided, generate generic recipes
      List<String> genericDishes = ['Vegetable Medley', 'Simple Pasta', 'Rice Bowl', 'Mixed Salad', 'Basic Soup'];
      
      for (int i = 0; i < additionalNeeded; i++) {
        String dish = genericDishes[i % genericDishes.length];
        String imageQuery = dish.toLowerCase().replaceAll(' ', '+');
        
        results.add(Recipe(
          id: 'mock-generic-${_random.nextInt(1000)}',
          title: dish,
          description: 'A simple $dish recipe.',
          ingredients: [
            Ingredient(name: 'Basic Ingredient ${i+1}', quantity: 'some'),
            Ingredient(name: 'Basic Ingredient ${i+2}', quantity: 'some'),
          ],
          instructions: ['Prepare ingredients.', 'Cook them.', 'Serve.'],
          preparationTime: 5,
          cookingTime: 10,
          servings: 2,
          difficulty: 'Easy',
          tags: ['Basic', 'Quick', 'Mock'],
          imageUrl: 'https://source.unsplash.com/featured/?food,$imageQuery',
        ));
      }
    }
    
    return results;
  }
}
