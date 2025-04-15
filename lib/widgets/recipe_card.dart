import 'package:ai_kitchen/widgets/recipe_image.dart';
import 'package:flutter/material.dart';
import 'package:ai_kitchen/models/recipe.dart';
import 'package:ai_kitchen/screens/recipe_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;

  const RecipeCard({
    super.key,
    required this.recipe,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
        ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeDetailScreen(recipe: recipe),
            ),
          );
        },
        // Use ConstrainedBox to ensure the card doesn't exceed a reasonable height
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 100,
            maxHeight: 350, // Reduced maximum height to prevent overflow
          ),
          child: SingleChildScrollView(
            // Allow scrolling if content exceeds the constraints
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Recipe Image - with fixed height to prevent layout issues
                if (recipe.imageUrl != null)
                  RecipeImage(
                    imageUrl: recipe.imageUrl,
                    recipeId: recipe.id,
                    height: 180,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        recipe.title,
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recipe.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6), // Reduced spacing
                      Row(
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 14, color: colorScheme.secondary), // Smaller icon
                          const SizedBox(width: 2),
                          Text('${recipe.preparationTime + recipe.cookingTime} min',
                              style: textTheme.bodySmall),
                          const SizedBox(width: 8), // Reduced spacing
                          Icon(Icons.whatshot_outlined,
                              size: 14, color: colorScheme.secondary), // Smaller icon
                          const SizedBox(width: 2),
                          Text(recipe.difficulty, style: textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 6), // Reduced spacing
                      if (recipe.tags.isNotEmpty)
                        SizedBox(
                          height: 28, // Fixed height for tags
                          child: ListView(
                            scrollDirection: Axis.horizontal, // Horizontal scrolling for tags
                            children: recipe.tags.take(3).map((tag) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Chip(
                                  label: Text(tag, style: const TextStyle(fontSize: 10)), // Smaller text
                                  backgroundColor: colorScheme.secondaryContainer.withOpacity(0.6),
                                  labelStyle: TextStyle(
                                      color: colorScheme.onSecondaryContainer,
                                      fontSize: 10), // Smaller text
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0), // Reduced padding
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact, // More compact
                                  side: BorderSide.none,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
