import 'package:flutter/material.dart';
import 'package:ai_kitchen/models/recipe.dart';
import 'package:carousel_slider/carousel_slider.dart' as cs;
import 'package:ai_kitchen/widgets/recipe_card.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RecipeOptions extends StatefulWidget {
  final List<Recipe> recipes;

  const RecipeOptions({
    super.key,
    required this.recipes,
  });

  @override
  State<RecipeOptions> createState() => _RecipeOptionsState();
}

class _RecipeOptionsState extends State<RecipeOptions> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Icon(Icons.restaurant_menu, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Recipe Suggestions',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        cs.CarouselSlider.builder(
          itemCount: widget.recipes.length,
          options: cs.CarouselOptions(
            height: 400, // Increased height for better image display
            viewportFraction: 0.85, // Show a bit of the next card
            enlargeCenterPage: true,
            autoPlay: true, // Enable auto-play for better engagement
            autoPlayInterval: const Duration(seconds: 5),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            onPageChanged: (index, reason) {
              setState(() => _currentIndex = index);
            },
          ),
          itemBuilder: (context, index, realIndex) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: RecipeCard(recipe: widget.recipes[index]),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: widget.recipes.asMap().entries.map((entry) {
            return Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withOpacity(
                      _currentIndex == entry.key ? 1 : 0.4,
                    ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
