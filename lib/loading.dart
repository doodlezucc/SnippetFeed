import 'package:flutter/material.dart';

class LoadingCircle extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const LoadingCircle({Key key, this.size = 16, this.color, this.strokeWidth})
      : super(key: key);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox.fromSize(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(
                color ?? Theme.of(context).textTheme.bodyText2.color),
            strokeWidth: strokeWidth ?? 3,
          ),
          size: Size.square(size),
        ),
      );
}
