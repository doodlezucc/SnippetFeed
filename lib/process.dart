import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:image/image.dart' as img;

final FlutterFFmpeg flutterFFmpeg = new FlutterFFmpeg();

Future<int> retrieveDuration(String path) async {
  Map<dynamic, dynamic> info = await flutterFFmpeg.getMediaInformation(path);
  int duration = info["duration"];
  print(duration);
  return duration;
}

img.Image _cropSquare(img.Image image, int size) {
  return img.bakeOrientation(img.copyResizeCropSquare(image, size));
}

Future<img.Image> createImage(
    {@required File front,
    @required File back,
    @required double frontM,
    @required int outSize,
    @required void Function(double progress) progressCb}) async {
  print("reading front...");
  var frontBytes = await front.readAsBytes();
  progressCb(0.1);
  print("reading back...");
  var backBytes = await back.readAsBytes();
  progressCb(0.2);
  print("preparing images...");
  img.Image out = img.decodeImage(backBytes);
  img.Image foreground = img.decodeImage(frontBytes);
  progressCb(0.25);

  out = _cropSquare(out, outSize);
  progressCb(0.5);
  foreground = _cropSquare(foreground, outSize);
  progressCb(0.75);

  int inset = (outSize * (0.5 - frontM * 0.5)).round();
  int size = (outSize * frontM).round();
  print("drawing foreground...");
  img.drawImage(out, foreground,
      dstX: inset, dstY: inset, dstW: size, dstH: size);
  progressCb(1.0);
  return out;
}

Future<File> makeImage(
    {@required File main,
    @required File background,
    @required File output,
    double frontSize = 0.8,
    int outSize = 1080,
    void Function(double progress) progressCallback}) async {
  var i = await createImage(
      back: background,
      front: main,
      frontM: frontSize,
      outSize: outSize,
      progressCb: progressCallback);
  var bytes = img.encodeJpg(i);
  if (!await output.exists()) {
    await output.create();
  }
  await output.writeAsBytes(bytes);
  print("written!");
  return output;
}

// combines an image and an audio file into a video running at 1 fps. cool.
Future<bool> makeVideo(String img, String audio, String output,
    void Function(int time) progressCb) async {
  print(img);
  print(audio);
  print(output);
  List<String> arguments = [
    "-r", "1", // input framerate = 1
    "-loop", "1", // loop that image
    "-i", "$img",
    "-i", "$audio",
    "-acodec", "copy", // use the original codec to preserve audio quality
    "-r", "1", // output framerate = 1
    "-shortest", // plz don't use the endless loop of a single image to figure out the vid length, doofus.
    "-y", // overwrite
    "$output" // output file
  ];
  bool initialized = false;
  flutterFFmpeg.enableStatisticsCallback((int time,
      int size,
      double bitrate,
      double speed,
      int videoFrameNumber,
      double videoQuality,
      double videoFps) {
    if (initialized) {
      progressCb(time);
    } else {
      initialized = true;
    }
  });
  int rc = await flutterFFmpeg.executeWithArguments(arguments);
  print("FFmpeg process exited with rc $rc");
  if (rc != 0 && File(output).existsSync()) {
    await File(output).delete();
  }
  return rc == 0;
}