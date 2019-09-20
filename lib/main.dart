import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File image;
  File audio;

  void doSthGoshDarnIt() async {
    var dir = await getApplicationDocumentsDirectory();
    makeVideo(image.path, audio.path, join(dir.path, "${DateTime.now().millisecondsSinceEpoch}.mp4"));
  }

  // combines an image and an audio file into a video running at 1 fps. cool.
  static void makeVideo(String img, String audio, String output) {
    print(img);
    print(audio);
    print(output);
    List<String> arguments = [
      "-r", "1", // input framerate = 1
      "-loop" "1" // loop that image
      "-i", "'$img'",
      "-i", "'$audio'",
      "-acodec", "copy", // use the original codec to preserve audio quality
      "-r", "1", // output framerate = 1
      "-shortest", // plz don't use the endless loop of a single image to figure out the vid length, doofus.
      "'$output'" // output file
    ];
    _flutterFFmpeg.executeWithArguments(arguments).then((rc) => print("FFmpeg process exited with rc $rc"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ffmpeg rulez"),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            RaisedButton(
              child: Text(image != null ? image : "Pick an image, pwease :3"),
              onPressed: () async {
                String path = await FilePicker.getFilePath(type: FileType.IMAGE);
                image = File(path);
                print("Picked an image i guess..? $path");
              },
            ),
            RaisedButton(
              child: Text(audio != null ? audio : "ever tried to kys? (pick audio)"),
              onPressed: () async {
                String path = await FilePicker.getFilePath(type: FileType.AUDIO);
                audio = File(path);
                print("Picked audio... $path");
              },
            ),
            RaisedButton(
              child: Text("do sth, make a video or some shiz"),
              onPressed: () {
                doSthGoshDarnIt();
              },
            )
          ],
        ),
      )
    );
  }
}
