import 'dart:io';

import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

Directory appDir;

Future<Directory> loadDirectory() async {
  try {
    appDir = await getExternalStorageDirectory();
    print('got external dir :)');
  } catch (e) {
    appDir = await getApplicationDocumentsDirectory();
    print('loser directory');
  }
  return appDir;
}

void share(File f) async {
  var bytes = await f.readAsBytes();
  var title = basename(f.path);
  await Share.file(title, title, bytes, "video/mp4");
}
