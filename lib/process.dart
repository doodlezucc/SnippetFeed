import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:image/image.dart' as img;

import 'buttons.dart';

final flutterFFmpeg = FlutterFFmpeg();
final flutterFFprobe = FlutterFFprobe();
final flutterFFmpegConfig = FlutterFFmpegConfig();

const String videoFormat = 'mp4';

Future<int> retrieveDuration(String path) async {
  Map<dynamic, dynamic> info = await flutterFFprobe.getMediaInformation(path);
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
    @required int outSize}) async {
  print("reading front...");
  var frontBytes = await front.readAsBytes();

  if (back == null) {
    var out = _cropSquare(img.decodeImage(frontBytes), outSize);
    return out;
  }

  print("reading back...");
  var backBytes = await back.readAsBytes();

  print("preparing images...");
  var out = img.decodeImage(backBytes);
  var foreground = img.decodeImage(frontBytes);

  out = _cropSquare(out, outSize);
  foreground = _cropSquare(foreground, outSize);

  var inset = (outSize * (0.5 - frontM * 0.5)).round();
  var size = (outSize * frontM).round();
  print("drawing foreground...");
  img.drawImage(out, foreground,
      dstX: inset, dstY: inset, dstW: size, dstH: size);
  return out;
}

Future<File> makeImage(
    {@required ConvertOptions conv,
    @required File output,
    @required int outSize}) async {
  var i = await createImage(
      back: conv.back.file,
      front: conv.front.file,
      frontM: conv.frontSize,
      outSize: outSize);
  var bytes = img.encodeTga(i);
  if (!await output.exists()) {
    await output.create();
  }
  await output.writeAsBytes(bytes);
  print("written!");
  return output;
}

// combines an image and an audio file into a video. cool.
Future<File> makeVideo(String img, String audio, String output,
    void Function(int time) progressCb) async {
  print(img);
  print(audio);
  print(output);
  List<String> arguments = [
    "-loop", "1", // loop that image
    //"-f", "image2",
    "-r", "6", // input framerate
    "-i", "$img",
    "-i", "$audio",
    "-c:v", "libx264",
    "-preset", "ultrafast",
    "-pix_fmt", "yuv420p",
    "-tune", "stillimage",
    "-vsync", "passthrough",
    //"-c:a", "copy", // use the original codec to preserve audio quality
    "-shortest", // plz don't use the endless loop of a single image to figure out the vid length, doofus.
    "-y", // overwrite
    //"-r", "12", // output framerate
    "$output" // output file
  ];
  bool initialized = false;
  flutterFFmpegConfig.enableStatisticsCallback((int time,
      int size,
      double bitrate,
      double speed,
      int videoFrameNumber,
      double videoQuality,
      double videoFps) {
    if (initialized) {
      progressCb(time);
    } else if (time < 5000) {
      initialized = true;
    }
  });
  int rc = await flutterFFmpeg.executeWithArguments(arguments);

  var out = File(output);

  if (rc != 0) {
    if (out.existsSync()) {
      await out.delete();
    }
    return null;
  }
  await flutterFFprobe.executeWithArguments([out.path]);
  return out;
}

mixin ConvertOptions {
  StatusFile front = StatusFile(type: FileType.image);
  StatusFile back = StatusFile(type: FileType.image);
  StatusFile audio = StatusFile(type: FileType.audio);

  double frontSize = 0.8;

  int durationInMs;
}
