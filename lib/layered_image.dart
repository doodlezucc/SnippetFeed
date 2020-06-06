import 'dart:io';

import 'package:flutter/material.dart';

class LayeredImage extends StatelessWidget {
  final File back;
  final File front;
  final double frontSize;

  const LayeredImage(
      {Key key,
      @required this.back,
      @required this.front,
      @required this.frontSize})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    var frontImage = Image(
      image: front != null
          ? FileImage(front)
          : AssetImage("assets/testpattern.png"),
      gaplessPlayback: true,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
          decoration: BoxDecoration(
              boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)]),
          child: back == null
              ? frontImage
              : Stack(
                  children: <Widget>[
                    Center(
                        child: Image(
                      image: FileImage(back),
                      gaplessPlayback: true,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )),
                    Transform.scale(
                      scale: frontSize,
                      child: Center(child: frontImage),
                    ),
                  ],
                )),
    );
  }
}
