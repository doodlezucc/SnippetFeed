import 'dart:io';
import 'dart:math' as math;

import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path/path.dart' as path;
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
        primarySwatch: Colors.purple,
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

class StatusFile {
  FileStatus status;
  File file;
  FileType type;

  StatusFile({@required this.type, this.status = FileStatus.NONE, this.file});
}

enum FileStatus { NONE, LOADING, FINISHED }

class _MyHomePageState extends State<MyHomePage> {
  StatusFile front = StatusFile(type: FileType.IMAGE);
  StatusFile back = StatusFile(type: FileType.IMAGE);
  StatusFile audio = StatusFile(type: FileType.AUDIO);

  double frontSize = 0.8;

  Directory appDir;
  int durationInMs;
  List<File> filesSorted;

  @override
  void initState() {
    super.initState();
    getApplicationDocumentsDirectory().then((dir) {
      appDir = dir;
      reloadFiles();
    });
  }

  // combines an image and an audio file into a video running at 1 fps. cool.
  Future<bool> makeVideo(String img, String audio, String output,
      void Function(double progress) progressCb) async {
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
    _flutterFFmpeg.enableStatisticsCallback((int time,
        int size,
        double bitrate,
        double speed,
        int videoFrameNumber,
        double videoQuality,
        double videoFps) {
      if (initialized) {
        progressCb(math.min(1, time.toDouble() / durationInMs.toDouble()));
      } else {
        initialized = true;
      }
    });
    int rc = await _flutterFFmpeg.executeWithArguments(arguments);
    print("FFmpeg process exited with rc $rc");
    if (rc != 0 && File(output).existsSync()) {
      await File(output).delete();
    }
    reloadFiles();
    return rc == 0;
  }

  void retrieveDuration() async {
    Map<dynamic, dynamic> info =
        await _flutterFFmpeg.getMediaInformation(audio.file.path);
    int duration = info["duration"];
    print(duration);
    durationInMs = duration;
  }

  void reloadFiles() {
    filesSorted = List<File>.from(
        appDir.listSync().where((entry) => entry.path.endsWith(".mp4")))
      ..sort((a, b) =>
          b.lastModifiedSync().millisecondsSinceEpoch -
          a.lastModifiedSync().millisecondsSinceEpoch);
    setState(() {});
  }

  void update(StatusFile file) => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("vinsta"),
        ),
        body: ListView(
          padding: EdgeInsets.all(20),
          children: <Widget>[
            FileChooseButton(
                chooseText: "Vordergrund auswählen",
                file: front,
                onUpdate: update),
            Container(
              color: Colors.amber,
              height: 400,
              child: Stack(
                children: <Widget>[
                  Center(
                      child: front.status == FileStatus.FINISHED
                          ? FadeInImage(
                              image: FileImage(front.file),
                              placeholder: MemoryImage(kTransparentImage),
                              fit: BoxFit.contain,
                              height: 400 * frontSize,
                            )
                          : Container()),
                  Center(
                      child: back.status == FileStatus.FINISHED
                          ? FadeInImage(
                              image: FileImage(back.file),
                              placeholder: MemoryImage(kTransparentImage),
                              fit: BoxFit.contain,
                            )
                          : Container()),
                ],
              ),
            ),
            Slider.adaptive(
                value: frontSize,
                onChanged: (v) {
                  setState(() {
                    frontSize = v;
                  });
                }),
            Divider(),
            FileChooseButton(
              chooseText: "Audio auswählen",
              file: audio,
              onUpdate: update,
            ),
            Divider(),
            RaisedButton(
              child: Text("In Video konvertieren"),
              onPressed: (audio.status != FileStatus.FINISHED ||
                      front.status != FileStatus.FINISHED)
                  ? null
                  : () {
                      var innerContext;
                      var setInnerState;

                      double progress = 0;
                      makeVideo(
                          front.file.path,
                          audio.file.path,
                          path.join(appDir.path,
                              "${path.basenameWithoutExtension(audio.file.path)}.mp4"),
                          (p) {
                        setInnerState(() {
                          progress = p;
                        });
                      }).then((v) {
                        Navigator.of(innerContext, rootNavigator: true).pop();
                      });

                      showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (c) =>
                              StatefulBuilder(builder: (ctx, setSt) {
                                innerContext = ctx;
                                setInnerState = setSt;
                                return WillPopScope(
                                  onWillPop: () async {
                                    return false;
                                  },
                                  child: AlertDialog(
                                    title: Text("Konvertiere in Video..."),
                                    content: Center(
                                      heightFactor: 1.0,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Text("${(progress * 100).round()}%"),
                                          LinearProgressIndicator(
                                            value: progress,
                                          )
                                        ],
                                      ),
                                    ),
                                    actions: <Widget>[
                                      FlatButton(
                                        child: Text("Abbrechen"),
                                        onPressed: () {
                                          _flutterFFmpeg.cancel();
                                        },
                                      )
                                    ],
                                  ),
                                );
                              }));
                    },
            ),
            appDir == null
                ? Container()
                : Column(
                    children: filesSorted
                        .map((f) => Container(
                              child: Row(
                                children: <Widget>[
                                  Expanded(child: Text(path.basename(f.path))),
                                  IconButton(
                                    icon: Icon(Icons.share),
                                    tooltip: "Teilen",
                                    onPressed: () async {
                                      var bytes = await f.readAsBytes();
                                      var title = path.basename(f.path);
                                      await Share.file(
                                          title, title, bytes, "video/mp4");
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete),
                                    tooltip: "Löschen",
                                    onPressed: () async {
                                      await f.delete();
                                      reloadFiles();
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

class FileChooseButton extends StatelessWidget {
  final StatusFile file;
  final void Function(StatusFile file) onUpdate;
  final String chooseText;

  const FileChooseButton(
      {Key key,
      @required this.file,
      @required this.chooseText,
      @required this.onUpdate})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        RaisedButton(
          child: Text(chooseText),
          onPressed: () async {
            onUpdate(file..status = FileStatus.LOADING);
            String path = await FilePicker.getFilePath(type: FileType.IMAGE);
            if (path != null) {
              onUpdate(file
                ..file = File(path)
                ..status = FileStatus.FINISHED);
            } else {
              onUpdate(file
                ..status =
                    file == null ? FileStatus.NONE : FileStatus.FINISHED);
            }
          },
        ),
        file.status == FileStatus.FINISHED
            ? Container()
            : Text(file.status == FileStatus.LOADING
                ? "Wird geladen..."
                : "Keine Datei ausgewählt")
      ],
    );
  }
}

class AudioItem extends StatefulWidget {
  final File file;

  const AudioItem({Key key, @required this.file}) : super(key: key);

  @override
  _AudioItemState createState() => _AudioItemState();
}

class _AudioItemState extends State<AudioItem> {
  static FlutterSound flutterSound = FlutterSound();
  static double currentPosition;
  bool isPlaying = false;
  double _seekbarProgress;
  double duration;

  static void maybeShutUp() {
    if (flutterSound.isPlaying) {
      flutterSound.stopPlayer();
    }
  }

  void _togglePlaying() async {
    if (isPlaying) {
      await flutterSound.stopPlayer();
      setState(() {
        isPlaying = false;
      });
    } else {
      if (flutterSound.isPlaying) {
        await flutterSound.stopPlayer();
      }
      await flutterSound.startPlayer(widget.file.uri.toString());
      isPlaying = true;

      flutterSound.onPlayerStateChanged.listen((status) {
        if (status != null) {
          duration = status.duration;
          currentPosition = status.currentPosition;
        }
        setState(() {});
      }, onDone: () {
        setState(() {
          isPlaying = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Duration d = isPlaying
        ? (_seekbarProgress == null
            ? Duration(milliseconds: currentPosition.toInt())
            : Duration(milliseconds: (duration * _seekbarProgress).toInt()))
        : Duration.zero;

    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () {
            _togglePlaying();
          },
          icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
        ),
        Expanded(
          child: isPlaying
              ? Slider.adaptive(
                  onChangeStart: (v) {
                    flutterSound.pausePlayer();
                  },
                  onChanged: (v) {
                    _seekbarProgress = v;
                  },
                  onChangeEnd: (v) {
                    currentPosition = duration * _seekbarProgress;
                    _seekbarProgress = null;
                    flutterSound.seekToPlayer((duration * v).toInt());
                    flutterSound.resumePlayer();
                  },
                  value: math.min(
                      1, _seekbarProgress ?? currentPosition / duration),
                )
              : Slider.adaptive(
                  onChanged: null,
                  value: 0,
                ),
        ),
        Text("${d.inMinutes % Duration.minutesPerHour}:"
            "${(d.inSeconds % Duration.secondsPerMinute).toString().padLeft(2, "0")}")
      ],
    );
  }
}
