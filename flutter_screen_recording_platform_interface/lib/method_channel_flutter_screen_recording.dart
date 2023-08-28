import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';

import 'flutter_screen_recording_platform_interface.dart';

class MethodChannelFlutterScreenRecording
    extends FlutterScreenRecordingPlatform {
  static const MethodChannel _channel =
      const MethodChannel('flutter_screen_recording');
      

  Future<MethodChannel?> createFlutterMethodChannel(String channelName, Future<dynamic> Function(MethodCall call)? handler) async {
    final bool isSuccess = await _channel
        .invokeMethod('addFlutterMethodChannel', {"channelName": channelName});
    if(isSuccess) {
      var channel = MethodChannel(channelName);
      channel.setMethodCallHandler(handler);
      return channel;
    }
  }
  

  Future<dynamic> callFlutterMethod(String channelName, String method, dynamic args) async {
    return await _channel
        .invokeMethod('callFlutterMethod', {"channelName": channelName, "method": method, "args": args});
  }


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

  Future<bool> initBroadcastConfig(String appGroup, String requestNotificationName, String responseNotificationName) async {
    // responseNotificationName
    final bool result = await _channel
        .invokeMethod('initBroadcastConfig', {
            "appGroup": appGroup,
            "requestNotificationName": requestNotificationName,
            "responseNotificationName": responseNotificationName,
        });
    return result;
  }

  Future<dynamic> postReplayKitBroadcast(Map<String, dynamic> args) async {
    // requestNotificationName
    final dynamic result = await _channel
        .invokeMethod('postReplayKitBroadcast', {
            "args": args,
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
