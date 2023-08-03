import 'dart:async';

import 'package:flutter/services.dart';

import 'flutter_screen_recording_platform_interface.dart';

class MethodChannelFlutterScreenRecording
    extends FlutterScreenRecordingPlatform {
  static const MethodChannel _channel =
      const MethodChannel('flutter_screen_recording');

  Future<bool> startRecordScreen(String name) async {
    final bool start = await _channel
        .invokeMethod('startRecordScreen', {"name": name, "audio": false});
    return start;
  }

  Future<bool> startCaptureScreen() async {
    final bool start = await _channel
        .invokeMethod('startCaptureScreen', {"audio": false});
    return start;
  }

  Future<Uint8List?> acquireLatestImage() async{
    return await _channel.invokeMethod('acquireLatestImage', {});
  }

  Future<bool> startRecordScreenAndAudio(String name) async {
    final bool start = await _channel
        .invokeMethod('startRecordScreen', {"name": name, "audio": true});
    return start;
  }

  Future<String> get stopRecordScreen async {
    final String path = await _channel.invokeMethod('stopRecordScreen');
    return path;
  }
  Future<bool> get stopCaptureScreen async {
    return await _channel.invokeMethod('stopCaptureScreen');
  }
  Future<bool> get isScreenOn async {
    return await _channel.invokeMethod('isScreenOn');
  }
}
