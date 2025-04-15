import 'package:flutter/material.dart';
import 'package:ai_kitchen/models/recipe.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:ai_kitchen/providers/recipe_provider.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  int _currentStep = -1; // Track currently spoken step

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US'); // Or make dynamic based on locale
    await _tts.setSpeechRate(0.5); // Adjust as needed

    _tts.setCompletionHandler(() {
      // Move to the next step automatically
      if (_isSpeaking && _currentStep < widget.recipe.instructions.length - 1) {
        setState(() {
          _currentStep++;
        });
        _speakStep(_currentStep);
      } else {
        // Reached end or stopped manually
        setState(() {
          _isSpeaking = false;
          _currentStep = -1;
        });
      }
    });

    _tts.setErrorHandler((msg) {
      // Using logger instead of print in production code
      debugPrint("TTS Error: $msg");
      setState(() {
        _isSpeaking = false;
        _currentStep = -1;
      });
      // Optionally show a snackbar
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Voice guidance error occurred')));
    });
  }

  // Handle pause/continue? (More complex state management)
  // _tts.setProgressHandler(...)

  Future<void> _speakStep(int step) async {
    if (step >= 0 && step < widget.recipe.instructions.length) {
      await _tts.speak(widget.recipe.instructions[step]);
    }
  }

  Future<void> _toggleSpeaking() async {
    if (_isSpeaking) {
      // Stop speaking
      await _tts.stop();
      setState(() {
        _isSpeaking = false;
        _currentStep = -1;
      });
    } else {
      // Start speaking from the beginning
      if (widget.recipe.instructions.isNotEmpty) {
        setState(() {
          _isSpeaking = true;
          _currentStep = 0;
        });
        await _speakStep(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe.title,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        actions: [
          // Favorite button
          Consumer<RecipeProvider>(builder: (context, recipeProvider, child) {
            final bool isFavorite = recipeProvider.isRecipeInFavorites(widget.recipe);
            return IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : null,
              ),
              tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
              onPressed: () {
                if (isFavorite) {
                  recipeProvider.removeFromFavorites(widget.recipe);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Removed from favorites')),
                  );
                } else {
                  recipeProvider.addToFavorites(widget.recipe);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to favorites')),
                  );
                }
              },
            );
          }),
          // TTS Play/Stop button in AppBar
          if (widget.recipe.instructions.isNotEmpty)
            IconButton(
              icon: Icon(_isSpeaking
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline),
              color: colorScheme.primary,
              iconSize: 30,
              tooltip:
                  _isSpeaking ? 'Stop Voice Guidance' : 'Start Voice Guidance',
              onPressed: _toggleSpeaking,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Image
            if (widget.recipe.imageUrl != null)
              Hero(
                tag: 'recipe-image-${widget.recipe.id}',
                child: CachedNetworkImage(
                  imageUrl: widget.recipe.imageUrl!,
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 250,
                    color: colorScheme.primaryContainer.withAlpha(76), // Using withAlpha instead of withOpacity
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 250,
                    color: colorScheme.primaryContainer.withAlpha(76), // Using withAlpha instead of withOpacity
                    child: Icon(Icons.restaurant, size: 60, color: colorScheme.primary),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(widget.recipe.description, style: textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  Divider(),
                  const SizedBox(height: 16),
            // Info Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoChip(Icons.timer_outlined,
                    '${widget.recipe.preparationTime} min', 'Prep', context),
                _buildInfoChip(Icons.whatshot_outlined,
                    '${widget.recipe.cookingTime} min', 'Cook', context),
                _buildInfoChip(Icons.people_outline,
                    '${widget.recipe.servings}', 'Servings', context),
                _buildInfoChip(Icons.thermostat_outlined,
                    widget.recipe.difficulty, 'Difficulty', context),
              ],
            ),
            const SizedBox(height: 16),
            Divider(),
            const SizedBox(height: 16),
            // Ingredients Section
            Text('Ingredients',
                style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: colorScheme.primary)),
            const SizedBox(height: 12),
            for (final ingredient in widget.recipe.ingredients)
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0, left: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.fiber_manual_record,
                      size: 8,
                      color: colorScheme.secondary.withOpacity(0.8),
                    ), // Bullet point
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: textTheme.bodyLarge, // Use default text style
                          children: [
                            TextSpan(
                              text: ingredient.quantity,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const TextSpan(text: ' '),
                            TextSpan(text: ingredient.name),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Divider(),
            const SizedBox(height: 16),
            // Instructions Section
            Text('Instructions',
                style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: colorScheme.primary)),
            const SizedBox(height: 12),
            for (int i = 0; i < widget.recipe.instructions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0, left: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}. ',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _currentStep == i
                            ? colorScheme.tertiary
                            : colorScheme.secondary, // Highlight current step
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.recipe.instructions[i],
                        style: textTheme.bodyLarge?.copyWith(
                          color: _currentStep == i
                              ? colorScheme.tertiary
                              : null, // Highlight current step
                          fontWeight:
                              _currentStep == i ? FontWeight.w500 : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Divider(),
            const SizedBox(height: 16),
            // Tags Section
            if (widget.recipe.tags.isNotEmpty)
              Text('Tags',
                  style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: colorScheme.primary)),
            if (widget.recipe.tags.isNotEmpty) const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.recipe.tags.map((tag) {
                return Chip(
                  label: Text(tag),
                  backgroundColor:
                      colorScheme.secondaryContainer.withOpacity(0.7),
                  labelStyle: TextStyle(
                      color: colorScheme.onSecondaryContainer, fontSize: 12),
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide.none,
                );
              }).toList(),
            ),
            const SizedBox(height: 20), // Keep bottom padding
                ],
              ),
            ),
          ],
        ),
      ), // End SingleChildScrollView
    ); // End Scaffold
  }

  Widget _buildInfoChip(
      IconData icon, String value, String label, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Icon(icon, color: colorScheme.secondary, size: 24),
        const SizedBox(height: 4),
        Text(value,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(label,
            style: textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
      ],
    );
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
