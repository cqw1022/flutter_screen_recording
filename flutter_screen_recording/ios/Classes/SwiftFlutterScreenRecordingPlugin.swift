import Flutter
import UIKit
import ReplayKit
import Photos
import Foundation

public class SwiftFlutterScreenRecordingPlugin: NSObject, FlutterPlugin {
    
    let recorder = RPScreenRecorder.shared()

    var videoOutputURL : URL?
    var videoWriter : AVAssetWriter?

    var audioInput:AVAssetWriterInput!
    var videoWriterInput : AVAssetWriterInput?
    var nameVideo: String = ""
    var recordAudio: Bool = false;
    var isStartCapture: Bool = false;
    var sampleBufferCache: [Data] = []
    let captureInterval = 0.3
    var captureWait = 0.0
    let maxCacheSize = 3
    var myResult: FlutterResult?
    let screenSize = UIScreen.main.bounds
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_screen_recording", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterScreenRecordingPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

        if(call.method == "startRecordScreen"){
            myResult = result
            let args = call.arguments as? Dictionary<String, Any>

            self.recordAudio = (args?["audio"] as? Bool)!
            self.nameVideo = (args?["name"] as? String)!+".mp4"
            startRecording()

        }else if(call.method == "stopRecordScreen"){
            if(videoWriter != nil){
                stopRecording()
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
                result(String(documentsPath.appendingPathComponent(nameVideo)))
            }
                result("")
        }else if(call.method == "startCaptureScreen"){
            myResult = result
            startCaptureScreen()
            //  let args = call.arguments as? Dictionary<String, Any>
            //  self.recordAudio = (args?["audio"] as? Bool)!
            //  self.nameVideo = (args?["name"] as? String)!+".mp4"
            //  startRecording()
        }else if(call.method == "acquireNextImage"){
            myResult = result
            //  let args = call.arguments as? Dictionary<String, Any>
            //  self.recordAudio = (args?["audio"] as? Bool)!
            //  self.nameVideo = (args?["name"] as? String)!+".mp4"
            //  startRecording()
            acquireNextImage()
        } else if (call.method == "getReadyImageCount") {
            result(self.sampleBufferCache.count)
            // result.success(readyImageCount);
        } else if (call.method == "stopCaptureScreen") {
            myResult = result
            stopCaptureScreen()
        }
        else if (call.method == "isScreenOn") {
            if(self.isStartCapture) {
                result(true)
            } else {
                result(false)
            }
        }
        else {
            result(false)
        }


    }

    
    @objc func startCaptureScreen() {
        if #available(iOS 11.0, *) {
            RPScreenRecorder.shared().isMicrophoneEnabled=false;
            RPScreenRecorder.shared().isCameraEnabled=false;
            RPScreenRecorder.shared().startCapture(
                handler: { [self] (cmSampleBuffer, rpSampleType, error) in
                guard error == nil else {
                    print("Error starting capture");
                    self.myResult!(false)
                    return;
                }

                switch rpSampleType {
                    case RPSampleBufferType.video:
                        print("writing sample....");
                        if(!self.isStartCapture) {
                            self.isStartCapture = true;
                            self.myResult!(true)
                            self.captureWait = 0
                        }


                        let currentTime = Date().timeIntervalSince1970
                        if(self.captureWait > currentTime ) {
                            return
                        }
                        print("writing sample....11111@@");
                        print("sample size", cmSampleBuffer.totalSampleSize);
                        self.captureWait = currentTime + self.captureInterval
                        if let blockBuffer = CMSampleBufferGetDataBuffer(cmSampleBuffer) {
                            print("writing sample....222222");
                            var dataPointer: UnsafeMutablePointer<Int8>?
                            var length = 0
                            CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

                            if let dataPointer = dataPointer {
                                let data = Data(bytes: dataPointer, count: length)
                                sampleBufferCache.append(data)
                                print("writing sample....333333");
                                while sampleBufferCache.count > maxCacheSize {
                                    sampleBufferCache.removeFirst()
                                }
                            }
                        }
                    default:
                        return;
                    // print("not a video sample, so ignore");
                }
            } ){(error) in
                guard error == nil else {
                    print("Screen record not allowed");
                    self.myResult!(false)
                    return;
                }
            }
        } else {
            //Fallback on earlier versions
        }
    }


    @objc func stopCaptureScreen() {
        if (!self.isStartCapture) {
            self.myResult!(true)
            return
        }
        if #available(iOS 11.0, *) {
            RPScreenRecorder.shared().stopCapture( handler: { (error) in
                print("stopping recording");
                self.isStartCapture = false
                self.captureWait = 0
                self.sampleBufferCache.removeAll()
                self.myResult!(true)
            })
        } else {
          //  Fallback on earlier versions
            self.myResult!(true)
        }
    }

    @objc func acquireNextImage() {
        while sampleBufferCache.count > 0 {
           let data = sampleBufferCache.removeFirst()
           self.myResult!(data)
           return
       }
       self.myResult!(nil)
    }

    @objc func startRecording() {

        //Use ReplayKit to record the screen
        //Create the file path to write to
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        self.videoOutputURL = URL(fileURLWithPath: documentsPath.appendingPathComponent(nameVideo))

        //Check the file does not already exist by deleting it if it does
        do {
            try FileManager.default.removeItem(at: videoOutputURL!)
        } catch {}

        do {
            try videoWriter = AVAssetWriter(outputURL: videoOutputURL!, fileType: AVFileType.mp4)
        } catch let writerError as NSError {
            print("Error opening video file", writerError);
            videoWriter = nil;
            return;
        }

        //Create the video settings
        if #available(iOS 11.0, *) {
            
            var codec = AVVideoCodecJPEG;
            
            if(recordAudio){
                codec = AVVideoCodecH264;
            }
            
            let videoSettings: [String : Any] = [
                AVVideoCodecKey  : codec,
                AVVideoWidthKey  : screenSize.width,
                AVVideoHeightKey : screenSize.height
            ]
                        
            if(recordAudio){
                
                let audioOutputSettings: [String : Any] = [
                    AVNumberOfChannelsKey : 2,
                    AVFormatIDKey : kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100,
                ]
                
                audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioOutputSettings)
                videoWriter?.add(audioInput)
            
            }


        //Create the asset writer input object whihc is actually used to write out the video
         videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings);
         videoWriter?.add(videoWriterInput!);
            
        }

        //Tell the screen recorder to start capturing and to call the handler
        if #available(iOS 11.0, *) {
            
            if(recordAudio){
                RPScreenRecorder.shared().isMicrophoneEnabled=true;
            }else{
                RPScreenRecorder.shared().isMicrophoneEnabled=false;

            }
            
            RPScreenRecorder.shared().startCapture(
            handler: { (cmSampleBuffer, rpSampleType, error) in
                guard error == nil else {
                    //Handle error
                    print("Error starting capture");
                    self.myResult!(false)
                    return;
                }

                switch rpSampleType {
                case RPSampleBufferType.video:
                    print("writing sample....");
                    if self.videoWriter?.status == AVAssetWriter.Status.unknown {

                        if (( self.videoWriter?.startWriting ) != nil) {
                            print("Starting writing");
                            self.myResult!(true)
                            self.videoWriter?.startWriting()
                            self.videoWriter?.startSession(atSourceTime:  CMSampleBufferGetPresentationTimeStamp(cmSampleBuffer))
                        }
                    }

                    if self.videoWriter?.status == AVAssetWriter.Status.writing {
                        if (self.videoWriterInput?.isReadyForMoreMediaData == true) {
                            print("Writting a sample");
                            if  self.videoWriterInput?.append(cmSampleBuffer) == false {
                                print(" we have a problem writing video")
                                self.myResult!(false)
                            }
                        }
                    }


                default:
                   print("not a video sample, so ignore");
                }
            } ){(error) in
                        guard error == nil else {
                           //Handle error
                           print("Screen record not allowed");
                           self.myResult!(false)
                           return;
                       }
                   }
        } else {
            //Fallback on earlier versions
        }
    }

    @objc func stopRecording() {
        //Stop Recording the screen
        if #available(iOS 11.0, *) {
            RPScreenRecorder.shared().stopCapture( handler: { (error) in
                print("stopping recording");
            })
        } else {
          //  Fallback on earlier versions
        }

        self.videoWriterInput?.markAsFinished();
        self.audioInput?.markAsFinished();
        
        self.videoWriter?.finishWriting {
            print("finished writing video");

            //Now save the video
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.videoOutputURL!)
            }) { saved, error in
                if saved {
                    let alertController = UIAlertController(title: "Your video was successfully saved", message: nil, preferredStyle: .alert)
                    let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alertController.addAction(defaultAction)
                    //self.present(alertController, animated: true, completion: nil)
                }
                if error != nil {
                    print("Video did not save for some reason", error.debugDescription);
                    debugPrint(error?.localizedDescription ?? "error is nil");
                }
            }
        }
    
}
    
}

// https://blog.csdn.net/jeffasd/article/details/80571366 

// import CoreVideo
// import CoreGraphics

// func convertToARGB(sampleBuffer: CMSampleBuffer) -> CGImage? {
//     guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
//         return nil
//     }

//     CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)

//     let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
//     let width = CVPixelBufferGetWidth(imageBuffer)
//     let height = CVPixelBufferGetHeight(imageBuffer)
//     let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
//     let colorSpace = CGColorSpaceCreateDeviceRGB()

//     let context = CGContext(data: baseAddress,
//                             width: width,
//                             height: height,
//                             bitsPerComponent: 8,
//                             bytesPerRow: bytesPerRow,
//                             space: colorSpace,
//                             bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)

//     let image = context?.makeImage()

//     CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)

//     return image
// }


// import cv2
// import numpy as np
// from CoreMedia import CVPixelBufferLockBaseAddress, CVPixelBufferGetBaseAddress, CVPixelBufferGetWidth, CVPixelBufferGetHeight, CVPixelBufferGetBytesPerRow, CVPixelBufferUnlockBaseAddress

// def convertSampleBufferToOpenCVRGBA(sampleBuffer):
//     imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
//     CVPixelBufferLockBaseAddress(imageBuffer, 0)
    
//     width = CVPixelBufferGetWidth(imageBuffer)
//     height = CVPixelBufferGetHeight(imageBuffer)
//     bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
    
//     baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
//     pixelData = np.frombuffer(baseAddress, dtype=np.uint8)
    
//     # Convert YUV420 to RGB
//     yuvImage = pixelData.reshape((int(1.5 * height), bytesPerRow))
//     rgbaImage = cv2.cvtColor(yuvImage, cv2.COLOR_YUV2RGBA_I420)
    
//     CVPixelBufferUnlockBaseAddress(imageBuffer, 0)
//     return rgbaImage

// # Usage
// if yourSampleBuffer is not None:
//     rgbaImage = convertSampleBufferToOpenCVRGBA(yourSampleBuffer)
//     cv2.imshow("OpenCV Image", rgbaImage)
//     cv2.waitKey(0)
//     cv2.destroyAllWindows()



// RPScreenRecorder 在录制屏幕时生成的 CMSampleBuffer 的像素格式通常是压缩后的 YUV 格式。这些样本缓冲区包含经过 H.264 编码的视频数据，其中 YUV 表示亮度（Y）和色度（U、V）分量。

// 具体来说，录制视频的 CMSampleBuffer 通常采用 kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange 或 kCVPixelFormatType_420YpCbCr8BiPlanarFullRange 这些格式，这两者都是表示 YUV420 平面格式的常见类型。

// kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange：这是一种视频范围的 YUV420 格式，其中亮度通道（Y）是完整范围，而色度通道（U、V）则在采样上进行了压缩。这通常是 H.264 编码后的像素格式。

// kCVPixelFormatType_420YpCbCr8BiPlanarFullRange：这是一种完整范围的 YUV420 格式，其中亮度和色度通道都是完整范围。在某些情况下，录制的视频可能会使用这种格式。

// 当你从 RPScreenRecorder 中获取 CMSampleBuffer 时，可以通过检查样本缓冲区的像素格式来了解实际使用的格式。可以使用 CVPixelBufferGetPixelFormatType 函数来获取像素格式类型。

// 以下是一个示例代码，展示如何获取 CMSampleBuffer 的像素格式类型：

// swift
// import ReplayKit

// func getPixelFormatFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> OSType {
//     guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
//         return 0
//     }
    
//     let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
//     return pixelFormat
// }

// // Usage
// if let sampleBuffer = yourSampleBuffer {
//     let pixelFormat = getPixelFormatFromSampleBuffer(sampleBuffer)
//     print("Pixel format: \(pixelFormat)")
// }
// 请注意，上述示例中的 getPixelFormatFromSampleBuffer 函数将获取到的像素格式类型打印出来。在使用实际的录制数据时，请根据像素格式类型进行相应的处理。