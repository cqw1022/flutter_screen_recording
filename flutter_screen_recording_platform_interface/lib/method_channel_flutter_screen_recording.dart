import 'dart:async';
import 'dart:ffi';
import 'dart:io';

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
  
  Future<bool> launchReplayKitBroadcast(String extensionName, Map<String, dynamic> setupInfo) async {
    // setupInfo
    // requestNotificationName
    // responsetNotificationName
    final bool start = await _channel
        .invokeMethod('launchReplayKitBroadcast', {
            "extensionName": extensionName,
            "setupInfo": setupInfo,
        });
    return start;
  }
  
  Future<bool> finishReplayKitBroadcast(String requestNotificationName) async {
    // requestNotificationName
    final bool start = await _channel
        .invokeMethod('finishReplayKitBroadcast', {
            "requestNotificationName": requestNotificationName,
        });
    return start;
  }

  Future<bool> initBroadcastConfig(String responseNotificationName) async {
    // responseNotificationName
    final bool result = await _channel
        .invokeMethod('initBroadcastConfig', {
            "responseNotificationName": responseNotificationName,
        });
    return result;
  }

  Future<String> postReplayKitBroadcast(String requestNotificationName) async {
    // requestNotificationName
    final String result = await _channel
        .invokeMethod('postReplayKitBroadcast', {
            "requestNotificationName": requestNotificationName,
        });
    return result;
  }

  Future<Uint8List?> acquireNextImage() async{
    return await _channel.invokeMethod('acquireNextImage', {});
  }
  
  Future<int> getReadyImageCount() async{
    return await _channel.invokeMethod('getReadyImageCount', {});
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
