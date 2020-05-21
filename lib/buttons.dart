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
                  color: Colors.black45,
                  child: Center(
                    child: Text(
                      text.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
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
