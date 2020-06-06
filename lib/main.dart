import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:vinsta/generated/i18n.dart';

import 'audio.dart';
import 'io.dart';
import 'process.dart';
import 'buttons.dart';
import 'layered_image.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final i18n = I18n.delegate;
    return MaterialApp(
      title: "vinsta",
      localizationsDelegates: [
        i18n,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: i18n.supportedLocales,
      localeResolutionCallback: i18n.resolution(fallback: Locale("en", "US")),
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
                                  text: I18n.of(context).front,
                                  file: front,
                                  onUpdate: update),
                              Expanded(child: Container(width: 16)),
                              ImagePickButton(
                                  text: I18n.of(context).back,
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
                        ? I18n.of(context).selectAudio.toUpperCase()
                        : (audio.status == FileStatus.LOADING
                            ? I18n.of(context).loading
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
                      if (file != null) {
                        didConvert = true;
                        reloadFiles();
                        if (filesSorted.length == 1) {
                          await Future.delayed(Duration(milliseconds: 200));
                          scroll.animateTo(scroll.position.maxScrollExtent,
                              duration: Duration(milliseconds: 500),
                              curve: Curves.ease);
                        }
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
                        onTap: () => print(OpenFile.open(f.path)),
                        child: Container(
                          padding: EdgeInsets.only(left: 12.0),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                  child: Text(
                                path.basenameWithoutExtension(f.path),
                                softWrap: false,
                                overflow: TextOverflow.fade,
                              )),
                              IconButton(
                                splashColor: Colors.white,
                                highlightColor: Colors.white,
                                icon: Icon(Icons.share),
                                tooltip: I18n.of(context).shareVideo,
                                onPressed: () => share(f),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete),
                                tooltip: I18n.of(context).delete,
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
