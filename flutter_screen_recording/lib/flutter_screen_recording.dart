import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_screen_recording_platform_interface/flutter_screen_recording_platform_interface.dart';
// import 'flutter_screen_recording_platform_interface/flutter_screen_recording_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';


class FlutterScreenRecording {
  
  static Future<MethodChannel?> createFlutterMethodChannel(String channelName, Future<dynamic> Function(MethodCall call)? handler, {String? titleNotification, String? messageNotification}) async {
    titleNotification ??= "";
    messageNotification ??= "";
    await _maybeStartFGS(titleNotification, messageNotification);
    
    return await FlutterScreenRecordingPlatform.instance.createFlutterMethodChannel(channelName, handler);
  }
  

  static Future<dynamic> callFlutterMethod(MethodChannel channel, String channelName, String method, dynamic args, {String? titleNotification, String? messageNotification}) async {
    titleNotification ??= "";
    messageNotification ??= "";
    await _maybeStartFGS(titleNotification, messageNotification);
    return await FlutterScreenRecordingPlatform.instance.callFlutterMethod(channel, channelName, method, args);
  }

  static Future<bool> startRecordScreen(String name, {String? titleNotification, String? messageNotification}) async{
    titleNotification ??= "";
    messageNotification ??= "";
    await _maybeStartFGS(titleNotification, messageNotification);
    final bool start = await FlutterScreenRecordingPlatform.instance.startRecordScreen(name);
    return start;
  }
  
  static Future<bool> startCaptureScreen({String? titleNotification, String? messageNotification}) async{
    titleNotification ??= "";
    messageNotification ??= "";
    await _maybeStartFGS(titleNotification, messageNotification);
    final bool start = await FlutterScreenRecordingPlatform.instance.startCaptureScreen();
    return start;
  }

  static Future<bool> launchReplayKitBroadcast(String extensionName, Map<String, dynamic> setupInfo, {String? titleNotification, String? messageNotification}) async{
    titleNotification ??= "";
    messageNotification ??= "";
    await _maybeStartFGS(titleNotification, messageNotification);
    final bool start = await FlutterScreenRecordingPlatform.instance.launchReplayKitBroadcast(extensionName, setupInfo);
    return start;
  }
  
  static Future<bool> finishReplayKitBroadcast(String requestNotificationName, {String? titleNotification, String? messageNotification}) async{
    titleNotification ??= "";
    messageNotification ??= "";
    await _maybeStartFGS(titleNotification, messageNotification);
    final bool start = await FlutterScreenRecordingPlatform.instance.finishReplayKitBroadcast(requestNotificationName);
    return start;
  }

  static Future<dynamic> postReplayKitBroadcast(Map<String, dynamic> args, {String? titleNotification, String? messageNotification}) async {
    titleNotification ??= "";
    messageNotification ??= "";
    await _maybeStartFGS(titleNotification, messageNotification);
    final dynamic start = await FlutterScreenRecordingPlatform.instance.postReplayKitBroadcast(args);
    return start;
  }

  static Future<bool> initBroadcastConfig(String appGroup, String requestNotificationName, String responseNotificationName, {String? titleNotification, String? messageNotification}) async{
    titleNotification ??= "";
    messageNotification ??= "";
    await _maybeStartFGS(titleNotification, messageNotification);
    final bool start = await FlutterScreenRecordingPlatform.instance.initBroadcastConfig(appGroup, requestNotificationName, responseNotificationName);
    return start;
  }

  static Future<bool> startCaptureScreenWithArgs(Map args, {String? titleNotification, String? messageNotification}) async{
    titleNotification ??= "";
    messageNotification ??= "";
    await _maybeStartFGS(titleNotification, messageNotification);
    final bool start = await FlutterScreenRecordingPlatform.instance.startCaptureScreenWithArgs(args);
    return start;
  }

  static Future<Uint8List?> acquireNextImage() async{
    return await FlutterScreenRecordingPlatform.instance.acquireNextImage();
  }

  Future<int> getReadyImageCount() async{
    return await FlutterScreenRecordingPlatform.instance.getReadyImageCount();
  }

  static Future<bool> startRecordScreenAndAudio(String name, {String? titleNotification, String? messageNotification}) async {
    //await _maybeStartFGS(titleNotification, messageNotification);
    final bool start = await FlutterScreenRecordingPlatform.instance.startRecordScreenAndAudio(name);
    return start;
  }

  static Future<String> get stopRecordScreen async {
    final String path = await FlutterScreenRecordingPlatform.instance.stopRecordScreen;
    if (!kIsWeb && Platform.isAndroid) {
      FlutterForegroundTask.stopService();
    }
    return path;
  }

  
  static Future<bool> get stopCaptureScreen async {
    final bool ret = await FlutterScreenRecordingPlatform.instance.stopCaptureScreen;
    if (!kIsWeb && Platform.isAndroid) {
      FlutterForegroundTask.stopService();
    }
    return ret;
  }

  static Future<bool> get isScreenOn async {
    final bool ret = await FlutterScreenRecordingPlatform.instance.isScreenOn;
    return ret;
  }

  static  _maybeStartFGS(String titleNotification, String? messageNotification) async {
    if (!kIsWeb && Platform.isAndroid) {

      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'notification_channel_id',
          channelName: titleNotification,
          channelDescription: messageNotification,
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          iconData: const NotificationIconData(
            resType: ResourceType.mipmap,
            resPrefix: ResourcePrefix.ic,
            name: 'launcher',
          ),
          buttons: [
            // const NotificationButton(id: 'sendButton', text: 'Send'),
            // const NotificationButton(id: 'testButton', text: 'Test'),
          ],
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: const ForegroundTaskOptions(
          interval: 5000,
          autoRunOnBoot: true,
          allowWifiLock: true,
        ),
      );
    }
  }

  static void globalForegroundService() {
    print("current datetime is ${DateTime.now()}");
  }
}
