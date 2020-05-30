import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import 'audio.dart';
import 'io.dart';
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
        sliderTheme: SliderThemeData(
          activeTickMarkColor: Colors.transparent,
          inactiveTickMarkColor: Colors.transparent,
        ),
        buttonTheme: ButtonThemeData(
          shape: StadiumBorder(),
        ),
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

class _MyHomePageState extends State<MyHomePage>
    with WidgetsBindingObserver, ConvertOptions {
  List<File> filesSorted = [];

  AudioController ctrl;
  ScrollController scroll = ScrollController();
  bool didConvert = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadDirectory().then((dir) => reloadFiles());
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  void reloadFiles() {
    filesSorted = List<File>.from(appDir
        .listSync()
        .where((entry) => entry.path.endsWith(".$videoFormat")))
      ..sort((a, b) =>
          b.lastModifiedSync().millisecondsSinceEpoch -
          a.lastModifiedSync().millisecondsSinceEpoch);
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AudioItem.maybeShutUp();
    }
  }

  void update(StatusFile file) => setState(() {});

  @override
  Widget build(BuildContext context) {
    var slider = Slider.adaptive(
        value: frontSize,
        min: 0.5,
        max: 1.0,
        divisions: 50,
        label: "${(frontSize * 100).round()}%",
        onChanged: back.file == null
            ? null
            : (v) {
                var value = (v * 100).roundToDouble() / 100;
                setState(() {
                  frontSize = value;
                });
              });

    return Scaffold(
        appBar: AppBar(
          title: Text("vinsta"),
        ),
        body: OrientationBuilder(
          builder: (ctx, orientation) {
            var portrait = orientation == Orientation.portrait;
            return ListView(
              padding: const EdgeInsets.all(12).copyWith(bottom: 8),
              controller: scroll,
              children: <Widget>[
                Flex(
                  direction: portrait ? Axis.vertical : Axis.horizontal,
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: <Widget>[
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(child: Container()),
                              ImagePickButton(
                                  text: "Vorder-Grund",
                                  file: front,
                                  onUpdate: update),
                              Expanded(child: Container(width: 16)),
                              ImagePickButton(
                                  text: "Hinter-Grund",
                                  file: back,
                                  onUpdate: update),
                              Expanded(child: Container()),
                            ],
                          ),
                          if (!portrait) Container(height: 16),
                          if (!portrait) slider,
                        ],
                      ),
                    ),
                    if (portrait) Container(height: 16),
                    Container(
                      height: MediaQuery.of(ctx).size.shortestSide * 0.6,
                      child: LayeredImage(
                          back: back.file,
                          front: front.file,
                          frontSize: frontSize),
                    ),
                  ],
                ),
                if (portrait) slider,
                Divider(),
                Center(
                  child: AudioPickButton(
                    text: audio.file == null
                        ? "Audio auswählen".toUpperCase()
                        : (audio.status == FileStatus.LOADING
                            ? "Wird geladen..."
                            : path.basename(audio.file.path)),
                    file: audio,
                    onUpdate: (f) async {
                      if (f.status == FileStatus.FINISHED) {
                        ctrl = AudioController(audio.file);
                        durationInMs = await retrieveDuration(f.file.path);
                      }
                      setState(() {});
                    },
                  ),
                ),
                if (audio.status == FileStatus.FINISHED)
                  AudioItem(controller: ctrl),
                Divider(),
                Center(
                  child: ConvertToVideoButton(
                    conv: this,
                    onDone: (file) async {
                      didConvert = true;
                      reloadFiles();
                      if (filesSorted.length == 1) {
                        await Future.delayed(Duration(milliseconds: 200));
                        scroll.animateTo(scroll.position.maxScrollExtent,
                            duration: Duration(milliseconds: 500),
                            curve: Curves.ease);
                      }
                    },
                  ),
                ),
                if (filesSorted.length > 0) Divider(),
                Column(
                    children: filesSorted.map((f) {
                  var isFirst = didConvert && f == filesSorted.first;

                  return Material(
                    shape: StadiumBorder(),
                    clipBehavior: Clip.hardEdge,
                    child: Ink(
                      color: isFirst
                          ? Theme.of(context).primaryColorLight
                          : Colors.transparent,
                      child: InkWell(
                        splashFactory: InkRipple.splashFactory,
                        splashColor: isFirst ? Colors.white54 : null,
                        enableFeedback: true,
                        onTap: () => print("preview me"),
                        child: Container(
                          padding: EdgeInsets.only(left: 12.0),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                  child: Text(
                                path.basenameWithoutExtension(f.path),
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                              )),
                              IconButton(
                                splashColor: Colors.white,
                                highlightColor: Colors.white,
                                icon: Icon(Icons.share),
                                tooltip: "Video teilen",
                                onPressed: () => share(f),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete),
                                tooltip: "Löschen",
                                onPressed: () async {
                                  if (isFirst) {
                                    didConvert = false;
                                  }
                                  await f.delete();
                                  reloadFiles();
                                },
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList())
              ],
            );
          },
        ));
  }
}
