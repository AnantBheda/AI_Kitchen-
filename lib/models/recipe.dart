class Ingredient {
  final String name;
  final String quantity;

  Ingredient({required this.name, required this.quantity});

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      name: map['name'] as String? ?? '',
      quantity: map['quantity'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
    };
  }
}

class Recipe {
  final String id;
  final String title;
  final String description;
  final List<Ingredient> ingredients;
  final List<String> instructions;
  final int preparationTime;
  final int cookingTime;
  final int servings;
  final String difficulty;
  final List<String> tags;
  final String? imageUrl; // URL for the recipe image

  Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.preparationTime,
    required this.cookingTime,
    required this.servings,
    required this.difficulty,
    required this.tags,
    this.imageUrl,
  });

  factory Recipe.fromMap(Map<String, dynamic> map) {
    int _parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return Recipe(
      id: map['id']?.toString() ??
          'gen-${DateTime.now().millisecondsSinceEpoch}',
      title: map['title'] as String? ?? 'Untitled Recipe',
      description: map['description'] as String? ?? '',
      ingredients: (map['ingredients'] as List<dynamic>? ?? [])
          .map((e) => Ingredient.fromMap(e as Map<String, dynamic>))
          .toList(),
      instructions: (map['instructions'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      preparationTime: _parseInt(map['preparationTime']),
      cookingTime: _parseInt(map['cookingTime']),
      servings: _parseInt(map['servings']),
      difficulty: map['difficulty'] as String? ?? 'Medium',
      tags: (map['tags'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      imageUrl: map['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'instructions': instructions,
      'preparationTime': preparationTime,
      'cookingTime': cookingTime,
      'servings': servings,
      'difficulty': difficulty,
      'tags': tags,
      'imageUrl': imageUrl,
    };
  }
}
