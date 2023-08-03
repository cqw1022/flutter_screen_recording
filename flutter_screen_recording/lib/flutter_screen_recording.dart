import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_screen_recording_platform_interface/flutter_screen_recording_platform_interface.dart';
// import 'flutter_screen_recording_platform_interface/flutter_screen_recording_platform_interface.dart';
import 'dart:async';
import 'dart:io';


class FlutterScreenRecording {
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

  static Future<Uint8List?> acquireLatestImage() async{
    return await FlutterScreenRecordingPlatform.instance.acquireLatestImage();
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
