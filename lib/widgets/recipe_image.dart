import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RecipeImage extends StatelessWidget {
  final String? imageUrl;
  final String recipeId;
  final double height;
  final BorderRadius? borderRadius;
  final bool useHero;

  const RecipeImage({
    super.key,
    required this.imageUrl,
    required this.recipeId,
    this.height = 160,
    this.borderRadius,
    this.useHero = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (imageUrl == null) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withOpacity(0.2),
          borderRadius: borderRadius,
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/images/recipe_placeholder.svg',
            height: height * 0.5,
            width: height * 0.5,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    final imageWidget = ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: height,
          color: colorScheme.primaryContainer.withOpacity(0.2),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              strokeWidth: 2.0,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          height: height,
          color: colorScheme.primaryContainer.withOpacity(0.2),
          child: Center(
            child: SvgPicture.asset(
              'assets/images/recipe_placeholder.svg',
              height: height * 0.5,
              width: height * 0.5,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );

    if (useHero) {
      return Hero(
        tag: 'recipe-image-$recipeId',
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}