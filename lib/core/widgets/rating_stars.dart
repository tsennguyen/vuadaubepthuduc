import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key, 
    required this.rating,
    this.size = 18,
  });

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fullStars = rating.floor();
    final halfStar = rating - fullStars >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (index == fullStars && halfStar) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        }
        return Icon(Icons.star_border, color: Colors.amber, size: size);
      }),
    );
  }
}
