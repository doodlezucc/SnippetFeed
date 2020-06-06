import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

AudioPlayer _player;

class AudioItem extends StatefulWidget {
  final AudioController controller;

  static void maybeShutUp() {
    _player?.stop();
  }

  const AudioItem({Key key, @required this.controller}) : super(key: key);

  @override
  _AudioItemState createState() => _AudioItemState();
}

class _AudioItemState extends State<AudioItem> {
  double _seekbarProgress;

  AudioPlayer get player => _player;
  AudioController get ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    print("ON INIT");
    ctrl.onUpdate = () => setState(() {});
  }

  @override
  void dispose() {
    print("DISPOSE");
    ctrl.onUpdate = () {
      print("disposed update call. huh.");
    };
    super.dispose();
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
                    player.pause();
                  },
                  onChanged: (v) {
                    setState(() {
                      _seekbarProgress = v;
                    });
                  },
                  onChangeEnd: (v) {
                    ctrl.currentPosition = ctrl.duration * _seekbarProgress;
                    _seekbarProgress = null;
                    player.seek(ctrl.duration * v);
                    player.resume();
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

  AudioController(this.file) {
    _player?.dispose();

    _player = AudioPlayer()
      ..onDurationChanged.listen((dur) {
        duration = dur;
      })
      ..onAudioPositionChanged.listen((disposition) {
        currentPosition = disposition;
        onUpdate();
      })
      ..onPlayerStateChanged.listen((state) {
        if (state == AudioPlayerState.COMPLETED ||
            state == AudioPlayerState.STOPPED) {
          _playing = false;
          onUpdate();
        }
      });
  }

  bool _playing = false;
  bool get playing => _playing;
  void setPlaying(bool playing) async {
    if (!playing) {
      await _player.stop();
      _playing = false;
    } else {
      currentPosition = Duration.zero;
      await _player.stop();
      await _player.play(file.uri.toString(), isLocal: true);
      _playing = true;
    }

    onUpdate();
  }
}
