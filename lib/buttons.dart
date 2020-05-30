import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import 'io.dart';
import 'process.dart';

class StatusFile {
  FileStatus status;
  File file;
  FileType type;

  StatusFile({@required this.type, this.status = FileStatus.NONE, this.file});
}

enum FileStatus { NONE, LOADING, FINISHED }

class FilePickButton extends StatelessWidget {
  final StatusFile file;
  final void Function(StatusFile file) onUpdate;
  final String text;

  const FilePickButton(
      {Key key,
      @required this.file,
      @required this.text,
      @required this.onUpdate})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        RaisedButton(
          child: Text(text),
          onPressed: file.status == FileStatus.LOADING ? null : pickFile,
        )
      ],
    );
  }

  void pickFile() async {
    onUpdate(file..status = FileStatus.LOADING);
    String path = await FilePicker.getFilePath(type: file.type);
    if (path != null) {
      onUpdate(file
        ..file = File(path)
        ..status = FileStatus.FINISHED);
    } else {
      onUpdate(file
        ..status = file.file == null ? FileStatus.NONE : FileStatus.FINISHED);
    }
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
                onTap: file.status == FileStatus.LOADING ? null : pickFile,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black26,
                  child: Center(
                    child: Text(
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
    return RaisedButton(
      child: Text("In Video konvertieren"),
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
                                            ? "Cover erstellen..."
                                            : "In Video konvertieren...",
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
                        //title: Text("Fertig!"),
                        contentPadding: EdgeInsets.all(space),
                        children: [
                          Text(
                            "Konvertierung erfolgreich!",
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
                              label: Text("Video teilen"),
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
