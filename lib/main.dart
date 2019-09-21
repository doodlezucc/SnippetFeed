import 'dart:io';

import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:transparent_image/transparent_image.dart';

final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "vinsta",
      theme: ThemeData(
        primarySwatch: Colors.brown,
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
  Directory appDir;

  @override
  void initState() {
    super.initState();
    getApplicationDocumentsDirectory().then((dir) {
      setState(() {
        appDir = dir;
      });
    });
  }

  void doSthGoshDarnIt() async {
    var dir = await getApplicationDocumentsDirectory();
    makeVideo(image.path, audio.path,
        join(dir.path, "${DateTime.now().millisecondsSinceEpoch}.mp4"));
  }

  // combines an image and an audio file into a video running at 1 fps. cool.
  void makeVideo(String img, String audio, String output) async {
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
      "$output" // output file
    ];
    _flutterFFmpeg.enableStatisticsCallback(statisticsCallback);
    int rc = await _flutterFFmpeg.executeWithArguments(arguments);
    print("FFmpeg process exited with rc $rc");
    setState(() {});
  }

  void statisticsCallback(int time, int size, double bitrate, double speed,
      int videoFrameNumber, double videoQuality, double videoFps) {
    print("jawrush");
    //print("Statistics: time: $time, size: $size, bitrate: $bitrate, speed: $speed, videoFrameNumber: $videoFrameNumber, videoQuality: $videoQuality, videoFps: $videoFps");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("vinsta"),
        ),
        body: ListView(
          padding: EdgeInsets.all(20),
          children: <Widget>[
            RaisedButton(
              child: Text("Pick image"),
              onPressed: () async {
                String path =
                    await FilePicker.getFilePath(type: FileType.IMAGE);
                image = File(path);
              },
            ),
            image != null
                ? Container(
                    margin: EdgeInsets.all(20),
                    child: FadeInImage(
                      image: FileImage(image),
                      placeholder: MemoryImage(kTransparentImage),
                      fit: BoxFit.cover,
                    ),
                    decoration: BoxDecoration(boxShadow: [
                      BoxShadow(blurRadius: 10, color: Colors.black38)
                    ]),
                  )
                : Text("No image selected"),
            Divider(),
            RaisedButton(
              child: Text("Pick audio"),
              onPressed: () async {
                String path =
                    await FilePicker.getFilePath(type: FileType.AUDIO);
                setState(() {
                  audio = File(path);
                });
              },
            ),
            audio != null ? Text("yes") : Text("No audio selected"),
            Divider(),
            RaisedButton(
              child: Text("Make video"),
              onPressed: () {
                doSthGoshDarnIt();
              },
            ),
            appDir == null
                ? Container()
                : Column(
                    children: appDir
                        .listSync()
                        //.where((entry) => entry.path.endsWith(".mp4"))
                        .map((f) => Container(
                              child: Row(
                                children: <Widget>[
                                  Expanded(child: Text(basename(f.path))),
                                  IconButton(
                                    icon: Icon(Icons.share),
                                    tooltip: "Share",
                                    onPressed: () async {
                                      var bytes =
                                          await (f as File).readAsBytes();
                                      var title = basename(f.path);
                                      await Share.file(
                                          title, title, bytes, "video/mp4");
                                    },
                                  )
                                ],
                              ),
                            ))
                        .toList())
          ],
        ));
  }
}
