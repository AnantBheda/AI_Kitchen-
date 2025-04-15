import 'package:flutter/material.dart';

class IngredientInput extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;

  const IngredientInput({
    super.key,
    required this.controller,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Add an ingredient...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onSubmitted(controller.text);
                controller.clear();
              }
            },
          ),
        ),
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            onSubmitted(value);
            controller.clear();
          }
        },
        textInputAction: TextInputAction.done,
      ),
    );
  }
}
