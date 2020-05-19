import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

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

  static const double previewSize = 40;
  static const double insets = 10;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text),
        Padding(
          padding: const EdgeInsets.only(top: 0, bottom: insets + 5),
          child: InkWell(
            onTap: file.status == FileStatus.LOADING ? null : pickFile,
            child: Container(
              child: Row(
                children: <Widget>[
                  Container(
                    width: previewSize + insets,
                    height: previewSize,
                    padding: const EdgeInsets.only(right: insets),
                    child: Image(
                      image: file.file != null
                          ? FileImage(file.file)
                          : AssetImage("assets/testpattern.png"),
                      gaplessPlayback: true,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      file.file != null
                          ? basename(file.file.path)
                          : "Kein Bild ausgewählt",
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
