import 'package:flutter/material.dart';

class StarRatingWidget extends StatefulWidget {
  final Function(double) onRatingChanged;

  const StarRatingWidget({super.key, required this.onRatingChanged});

  @override
  State<StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget> {
  double rating = 0;

  Widget buildStar(int index) {
    return IconButton(
      icon: Icon(
        index < rating ? Icons.star : Icons.star_border,
        color: Colors.amber,
        size: 32,
      ),
      onPressed: () {
        setState(() {
          rating = index + 1.0;
        });

        widget.onRatingChanged(rating);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) => buildStar(index)),
    );
  }
}
