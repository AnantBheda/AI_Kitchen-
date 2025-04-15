import 'package:flutter/material.dart';
import 'package:ai_kitchen/models/recipe.dart';

class RecipeFilter extends StatefulWidget {
  final List<Recipe> recipes;
  final Function(List<Recipe>) onFilterChanged;

  const RecipeFilter({
    super.key,
    required this.recipes,
    required this.onFilterChanged,
  });

  @override
  State<RecipeFilter> createState() => _RecipeFilterState();
}

class _RecipeFilterState extends State<RecipeFilter> {
  String? _selectedDifficulty;
  String? _selectedTag;
  RangeValues? _timeRange;
  
  // Get all unique tags from recipes
  List<String> get _allTags {
    final Set<String> tags = {};
    for (final recipe in widget.recipes) {
      tags.addAll(recipe.tags);
    }
    return tags.toList()..sort();
  }
  
  // Get all unique difficulties from recipes
  List<String> get _allDifficulties {
    final Set<String> difficulties = {};
    for (final recipe in widget.recipes) {
      difficulties.add(recipe.difficulty);
    }
    return difficulties.toList()..sort();
  }
  
  // Get min and max preparation+cooking time
  RangeValues get _timeRangeBounds {
    int minTime = 9999;
    int maxTime = 0;
    
    for (final recipe in widget.recipes) {
      final totalTime = recipe.preparationTime + recipe.cookingTime;
      if (totalTime < minTime) minTime = totalTime;
      if (totalTime > maxTime) maxTime = totalTime;
    }
    
    return RangeValues(minTime.toDouble(), maxTime.toDouble());
  }
  
  // Apply filters and update parent
  void _applyFilters() {
    List<Recipe> filteredRecipes = List.from(widget.recipes);
    
    // Filter by difficulty
    if (_selectedDifficulty != null) {
      filteredRecipes = filteredRecipes
          .where((recipe) => recipe.difficulty == _selectedDifficulty)
          .toList();
    }
    
    // Filter by tag
    if (_selectedTag != null) {
      filteredRecipes = filteredRecipes
          .where((recipe) => recipe.tags.contains(_selectedTag))
          .toList();
    }
    
    // Filter by time range
    if (_timeRange != null) {
      filteredRecipes = filteredRecipes.where((recipe) {
        final totalTime = recipe.preparationTime + recipe.cookingTime;
        return totalTime >= _timeRange!.start && totalTime <= _timeRange!.end;
      }).toList();
    }
    
    widget.onFilterChanged(filteredRecipes);
  }
  
  // Reset all filters
  void _resetFilters() {
    setState(() {
      _selectedDifficulty = null;
      _selectedTag = null;
      _timeRange = null;
    });
    widget.onFilterChanged(widget.recipes);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bounds = _timeRangeBounds;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filter Recipes', style: textTheme.titleMedium),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reset'),
                  onPressed: _resetFilters,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            
            // Difficulty filter
            if (_allDifficulties.isNotEmpty) ...[  
              Text('Difficulty:', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final difficulty in _allDifficulties)
                    ChoiceChip(
                      label: Text(difficulty),
                      selected: _selectedDifficulty == difficulty,
                      onSelected: (selected) {
                        setState(() {
                          _selectedDifficulty = selected ? difficulty : null;
                        });
                        _applyFilters();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Tags filter
            if (_allTags.isNotEmpty) ...[  
              Text('Tags:', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final tag in _allTags)
                    ChoiceChip(
                      label: Text(tag),
                      selected: _selectedTag == tag,
                      onSelected: (selected) {
                        setState(() {
                          _selectedTag = selected ? tag : null;
                        });
                        _applyFilters();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Time range filter
            Text('Total Time (min):', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(bounds.start.toInt().toString()),
                Expanded(
                  child: RangeSlider(
                    values: _timeRange ?? bounds,
                    min: bounds.start,
                    max: bounds.end,
                    divisions: (bounds.end - bounds.start) > 10 ? 
                      ((bounds.end - bounds.start) / 5).floor() : null,
                    labels: RangeLabels(
                      (_timeRange?.start.toInt() ?? bounds.start.toInt()).toString(),
                      (_timeRange?.end.toInt() ?? bounds.end.toInt()).toString(),
                    ),
                    onChanged: (values) {
                      setState(() {
                        _timeRange = values;
                      });
                      _applyFilters();
                    },
                  ),
                ),
                Text(bounds.end.toInt().toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}