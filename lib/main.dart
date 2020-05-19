import 'dart:io';
import 'dart:math' as math;

import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound_player.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'process.dart';
import 'buttons.dart';
import 'layered_image.dart';

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

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  StatusFile front = StatusFile(type: FileType.image);
  StatusFile back = StatusFile(type: FileType.image);
  StatusFile audio = StatusFile(type: FileType.audio);

  double frontSize = 0.8;

  Directory appDir;
  int durationInMs;
  List<File> filesSorted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadDirectory();
  }

  void loadDirectory() async {
    try {
      appDir = await getExternalStorageDirectory();
      print('got external dir :)');
    } catch (e) {
      appDir = await getApplicationDocumentsDirectory();
      print('loser directory');
    } finally {
      reloadFiles();
    }
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  void reloadFiles() {
    filesSorted = List<File>.from(
        appDir.listSync().where((entry) => entry.path.endsWith(".mp4")))
      ..sort((a, b) =>
          b.lastModifiedSync().millisecondsSinceEpoch -
          a.lastModifiedSync().millisecondsSinceEpoch);
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _AudioItemState.maybeShutUp();
    }
  }

  void update(StatusFile file) => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("vinsta"),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            ImagePickButton(text: "Vordergrund", file: front, onUpdate: update),
            ImagePickButton(text: "Hintergrund", file: back, onUpdate: update),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: LayeredImage(
                  back: back.file, front: front.file, frontSize: frontSize),
            ),
            Slider.adaptive(
                value: frontSize,
                min: 0.5,
                max: 1.0,
                divisions: 50,
                label: "${(frontSize * 100).round()}%",
                onChanged: (v) {
                  var value = (v * 100).roundToDouble() / 100;
                  setState(() {
                    frontSize = value;
                  });
                }),
            Divider(),
            FilePickButton(
              text: "Audio auswählen",
              file: audio,
              onUpdate: (f) async {
                if (f.status == FileStatus.FINISHED) {
                  durationInMs = await retrieveDuration(f.file.path);
                }
                setState(() {});
              },
            ),
            audio.status == FileStatus.FINISHED
                ? AudioItem(file: audio.file)
                : Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Center(
                      child: Text(audio.status == FileStatus.LOADING
                          ? "Wird geladen..."
                          : "Keine Datei ausgewählt"),
                    ),
                  ),
            Divider(),
            RaisedButton(
              child: Text("In Video konvertieren"),
              onPressed: (audio.status != FileStatus.FINISHED ||
                      front.status != FileStatus.FINISHED)
                  ? null
                  : () {
                      var innerContext;
                      void Function(void Function()) setInnerState = (bruv) {};
                      int step = 0;
                      var fileBase =
                          path.basenameWithoutExtension(audio.file.path);

                      double progress = 0;

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
                                    title: Text("Video wird erstellt..."),
                                    content: Center(
                                      heightFactor: 1.0,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Text((step == 0
                                                  ? "Cover wird erstellt..."
                                                  : "In Video konvertieren...") +
                                              " ${(progress * 100).round()}%"),
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
                                          flutterFFmpeg.cancel();
                                        },
                                      )
                                    ],
                                  ),
                                );
                              }));

                      makeImage(
                          background: back.file,
                          main: front.file,
                          frontSize: frontSize,
                          outSize: 600,
                          output: File(path.join(appDir.path, "$fileBase.jpg")),
                          progressCallback: (v) {
                            print("Progress: $v");
                            progress = v;
                            setInnerState(() {});
                          }).then((file) {
                        step = 1;
                        makeVideo(file.path, audio.file.path,
                            path.join(appDir.path, "$fileBase.mp4"), (p) {
                          progress = math.min(
                              1, p.toDouble() / durationInMs.toDouble());
                          setInnerState(() {});
                        }).then((v) {
                          reloadFiles();
                          Navigator.of(innerContext, rootNavigator: true).pop();
                        });
                      });
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

class AudioItem extends StatefulWidget {
  final File file;

  const AudioItem({Key key, @required this.file}) : super(key: key);

  @override
  _AudioItemState createState() => _AudioItemState();
}

class _AudioItemState extends State<AudioItem> {
  static FlutterSoundPlayer flutterSound = FlutterSoundPlayer();
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
