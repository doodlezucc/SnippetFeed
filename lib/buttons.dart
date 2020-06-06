import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:vinsta/loading.dart';

import 'generated/i18n.dart';
import 'io.dart';
import 'process.dart';

class StatusFile {
  FileStatus status;
  File file;
  FileType type;

  StatusFile({@required this.type, this.status = FileStatus.NONE, this.file});

  void updateStatus() {
    status = file == null ? FileStatus.NONE : FileStatus.FINISHED;
  }
}

enum FileStatus { NONE, LOADING, FINISHED }

abstract class FilePickButton extends StatelessWidget {
  final StatusFile file;
  final void Function(StatusFile file) onUpdate;
  final String text;

  const FilePickButton(
      {Key key,
      @required this.file,
      @required this.text,
      @required this.onUpdate})
      : super(key: key);

  void pickFile() async {
    onUpdate(file..status = FileStatus.LOADING);
    String path;
    try {
      path = await FilePicker.getFilePath(type: file.type);

      if (path != null) {
        onUpdate(file
          ..file = File(path)
          ..status = FileStatus.FINISHED);
      } else {
        onUpdate(file..updateStatus());
      }
    } catch (e) {
      onUpdate(file..updateStatus());
      print(e);
    }
  }

  void Function() get tryPickFile =>
      file.status == FileStatus.LOADING ? null : pickFile;
}

class AudioPickButton extends FilePickButton {
  const AudioPickButton(
      {Key key,
      @required StatusFile file,
      @required String text,
      @required void Function(StatusFile) onUpdate})
      : super(key: key, file: file, text: text, onUpdate: onUpdate);

  @override
  Widget build(BuildContext context) {
    return FlatButton.icon(
      onPressed: tryPickFile,
      label: Flexible(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              flex: 1,
              child: Text(
                text,
                overflow: TextOverflow.fade,
                softWrap: false,
                textAlign: TextAlign.center,
              ),
            ),
            if (file.status == FileStatus.LOADING) LoadingCircle()
          ],
        ),
      ),
      icon: Icon(Icons.audiotrack),
    );
  }
}

class ImagePickButton extends FilePickButton {
  const ImagePickButton(
      {Key key,
      @required StatusFile file,
      @required String text,
      @required void Function(StatusFile) onUpdate})
      : super(key: key, file: file, text: text, onUpdate: onUpdate);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 110,
        height: 110,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image(
              image: file.file != null
                  ? FileImage(file.file)
                  : AssetImage("assets/testpattern.png"),
              gaplessPlayback: true,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: tryPickFile,
                splashFactory: InkRipple.splashFactory,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black26,
                  child: Center(
                    child: file.status == FileStatus.LOADING
                        ? LoadingCircle(
                            size: 50, color: Colors.white, strokeWidth: 5)
                        : Text(
                            text.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: Colors.black38, blurRadius: 10)
                                ]),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConvertToVideoButton extends StatelessWidget {
  final ConvertOptions conv;
  final void Function(File file) onDone;

  const ConvertToVideoButton(
      {Key key, @required this.conv, @required this.onDone})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FlatButton.icon(
      icon: Icon(Icons.movie),
      label: Text(I18n.of(context).convert.toUpperCase()),
      onPressed: (conv.audio.status != FileStatus.FINISHED ||
              conv.front.status != FileStatus.FINISHED)
          ? null
          : () {
              var innerContext;
              void Function(void Function()) setInnerState = (bruv) {};
              int step = 0;
              var fileBase = basenameWithoutExtension(conv.audio.file.path);

              double progress = 0;

              var style = TextStyle(fontSize: 16);
              const space = 16.0;

              showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (c) => StatefulBuilder(builder: (ctx, setSt) {
                        innerContext = ctx;
                        setInnerState = setSt;
                        return WillPopScope(
                          onWillPop: () async {
                            return false;
                          },
                          child: SimpleDialog(
                            contentPadding: EdgeInsets.zero,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(space),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        step == 0
                                            ? I18n.of(context).creatingCover
                                            : I18n.of(context)
                                                .convertingToVideo,
                                        style: style,
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                            value: progress),
                                        CloseButton(
                                          onPressed: () {
                                            flutterFFmpeg.cancel();
                                          },
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        );
                      }));

              makeImage(
                  conv: conv,
                  outSize: 1080,
                  output: File(join(appDir.path, "$fileBase.tga")),
                  progressCallback: (v) {
                    print("Progress: $v");
                    progress = v;
                    setInnerState(() {});
                  }).then((file) {
                step = 1;
                makeVideo(file.path, conv.audio.file.path,
                    join(appDir.path, "$fileBase.$videoFormat"), (p) {
                  progress =
                      min(1, p.toDouble() / conv.durationInMs.toDouble());
                  setInnerState(() {});
                }).then((file) {
                  onDone(file);
                  Navigator.of(innerContext, rootNavigator: true).pop();
                  if (file != null) {
                    showDialog(
                      context: context,
                      builder: (c) => SimpleDialog(
                        contentPadding: EdgeInsets.all(space),
                        children: [
                          Text(
                            I18n.of(context).conversionSuccess,
                            style: style,
                          ),
                          Container(height: space),
                          Center(
                            child: FlatButton.icon(
                              onPressed: () {
                                share(file);
                                Navigator.of(context, rootNavigator: true)
                                    .pop();
                              },
                              icon: Icon(Icons.share),
                              label: Text(I18n.of(context).shareVideo),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                });
              });
            },
    );
  }
}
