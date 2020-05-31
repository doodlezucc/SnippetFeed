import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_sound_lite/flutter_sound.dart';

final FlutterSoundPlayer _flutterSound = FlutterSoundPlayer();

class AudioItem extends StatefulWidget {
  final AudioController controller;

  static void maybeShutUp() {
    if (_flutterSound.isPlaying) {
      _flutterSound.stopPlayer();
    }
  }

  const AudioItem({Key key, @required this.controller}) : super(key: key);

  @override
  _AudioItemState createState() => _AudioItemState();
}

class _AudioItemState extends State<AudioItem> {
  double _seekbarProgress;

  FlutterSoundPlayer get flutterSound => _flutterSound;
  AudioController get ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    ctrl.onUpdate = () => setState(() {});
  }

  void _togglePlaying() async {
    ctrl.setPlaying(!ctrl.playing);
  }

  @override
  Widget build(BuildContext context) {
    Duration d = ctrl.playing
        ? (_seekbarProgress == null
            ? ctrl.currentPosition
            : ctrl.duration * _seekbarProgress)
        : Duration.zero;

    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () {
            _togglePlaying();
          },
          icon: Icon(ctrl.playing ? Icons.stop : Icons.play_arrow),
        ),
        Expanded(
          child: ctrl.playing
              ? Slider.adaptive(
                  onChangeStart: (v) {
                    flutterSound.pausePlayer();
                  },
                  onChanged: (v) {
                    _seekbarProgress = v;
                  },
                  onChangeEnd: (v) {
                    ctrl.currentPosition = ctrl.duration * _seekbarProgress;
                    _seekbarProgress = null;
                    flutterSound.seekToPlayer(ctrl.duration * v);
                    flutterSound.resumePlayer();
                  },
                  value: min(
                    1,
                    _seekbarProgress ??
                        ctrl.currentPosition.inMilliseconds /
                            ctrl.duration.inMilliseconds,
                  ),
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

class AudioController {
  final File file;

  void Function() onUpdate;
  Duration currentPosition = Duration.zero;
  Duration duration = Duration(seconds: 1);

  AudioController(this.file);

  bool _playing = false;
  bool get playing => _playing;
  void setPlaying(bool playing) async {
    if (!playing) {
      await _flutterSound.stopPlayer();
      _playing = false;
    } else {
      if (_flutterSound.isPlaying) {
        await _flutterSound.stopPlayer();
      }
      await _flutterSound.startPlayer(fromURI: file.uri.toString());
      _playing = true;

      _flutterSound.onProgress.listen((disposition) {
        duration = disposition.duration;
        currentPosition = disposition.position;
        onUpdate();
      }, onDone: () {
        _playing = false;
        onUpdate();
      });
    }

    onUpdate();
  }
}
