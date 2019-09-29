import 'dart:io';

import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';

final FlutterFFmpeg flutterFFmpeg = new FlutterFFmpeg();

Future<int> retrieveDuration(String path) async {
  Map<dynamic, dynamic> info = await flutterFFmpeg.getMediaInformation(path);
  int duration = info["duration"];
  print(duration);
  return duration;
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
