import Flutter
import UIKit
import ReplayKit
import Photos
import Foundation
import MMWormhole

public class SwiftFlutterScreenRecordingPlugin: RPBroadcastSampleHandler, FlutterPlugin, RPBroadcastControllerDelegate {
    
    let recorder = RPScreenRecorder.shared()
    let broadcastController = RPBroadcastController()

    var videoOutputURL : URL?
    var videoWriter : AVAssetWriter?

    var audioInput:AVAssetWriterInput!
    var videoWriterInput : AVAssetWriterInput?
    var nameVideo: String = ""
    var recordAudio: Bool = false;
    var isStartCapture: Bool = false;
    var sampleBufferCache: [CMSampleBuffer] = []
    var captureInterval = 0.1
    var captureWait = 0.0
    var maxCacheSize = 3
    var myResult: FlutterResult?
    var flutterResults: [Int:FlutterResult] = [:]
    let screenSize = UIScreen.main.bounds
//    let notificationCenter:CFNotificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
    var postReplayKitBroadcastResultId = 0
    var mmwormhole: MMWormhole?
    var requestNotificationName: String?
    var responseNotificationName: String?
    var callFlutterChannels: [String:FlutterMethodChannel] = [:]
    var registrar: FlutterPluginRegistrar?
    
    static var instance:SwiftFlutterScreenRecordingPlugin?;
    public static func getInstance() -> SwiftFlutterScreenRecordingPlugin {
        return instance!
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_screen_recording", binaryMessenger: registrar.messenger())
        instance = SwiftFlutterScreenRecordingPlugin()
        instance!.registrar = registrar
//        instance?.callFlutterChannel = FlutterMethodChannel(name: "flutter_screen_recording_callback", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance!, channel: channel)
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
            let args = call.arguments as? Dictionary<String, Any>
            self.captureInterval = (args?["captureInterval"] as? Double)!
            self.maxCacheSize = (args?["maxCacheSize"] as? Int)!
            // startBroadcast()
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
        } else if (call.method == "launchReplayKitBroadcast") {
            myResult = result
            let args = call.arguments as? Dictionary<String, Any>
            launchReplayKitBroadcast(extensionName: (args?["extensionName"] as? String)!, setupInfo: (args?["setupInfo"] as? Dictionary<String, Any>)!)
//            result(true)
        } else if (call.method == "finishReplayKitBroadcast") {
            let args = call.arguments as? Dictionary<String, Any>
            var notificationArgs = (args?["args"] as? Dictionary<String, Any>)!
//            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName.init((args?["requestNotificationName"] as? String)! as CFString), nil, notificationArgs as CFDictionary, true);
//            result(true)
            postReplayKitBroadcastResultId = postReplayKitBroadcastResultId + 1;
            notificationArgs["resultId"] = postReplayKitBroadcastResultId;
            notificationArgs["cmd"] = "finishReplayKitBroadcast";
            flutterResults[postReplayKitBroadcastResultId] = result
            self.mmwormhole?.passMessageObject(notificationArgs as NSCoding, identifier: self.requestNotificationName!)
        } else if (call.method == "postReplayKitBroadcast") {
            let args = call.arguments as? Dictionary<String, Any>
            var notificationArgs = (args?["args"] as? Dictionary<String, Any>)!
            var cmd = (notificationArgs["cmd"] as? String)!
            // let resultId = (notificationArgs["resultId"] as? Int)!
            if cmd == "requestNextImage" {
                
                notificationArgs["resultId"] = -2;
                
                if let resultcb = SwiftFlutterScreenRecordingPlugin.instance?.flutterResults[-2] {
                    SwiftFlutterScreenRecordingPlugin.instance?.flutterResults.removeValue(forKey: -2)
                    resultcb(nil)
                }
                flutterResults[-2] = result
//                myResult = result
            } else {
                
                postReplayKitBroadcastResultId = postReplayKitBroadcastResultId + 1;
                notificationArgs["resultId"] = postReplayKitBroadcastResultId;
                flutterResults[postReplayKitBroadcastResultId] = result
            }
            
            self.mmwormhole?.passMessageObject(notificationArgs as NSCoding, identifier: self.requestNotificationName!)
//            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName.init((args?["requestNotificationName"] as? String)! as CFString), nil, notificationArgs as CFDictionary, true);
        } else if (call.method == "initBroadcastConfig") {
            let args = call.arguments as? Dictionary<String, Any>
            let appGroup:String? = args?["appGroup"] as? String
            self.requestNotificationName = args?["requestNotificationName"] as? String
            self.responseNotificationName = args?["responseNotificationName"] as? String
            self.mmwormhole = MMWormhole(applicationGroupIdentifier: appGroup!, optionalDirectory: appGroup!)
            self.mmwormhole?.listenForMessage(withIdentifier: (args?["responseNotificationName"] as? String)!, listener: { (messageObject) -> Void in
                if let message: [String:Any] = messageObject as? [String:Any] {
                    if let resultId = message["resultId"] as? Int {
                        if resultId == -2 {
                            if let resultcb = SwiftFlutterScreenRecordingPlugin.instance?.flutterResults[resultId] {
                                SwiftFlutterScreenRecordingPlugin.instance?.flutterResults.removeValue(forKey: resultId)
                                var data: Data = (message["data"] as? Data)!
                                if(data.count > 0) {
                                    
//                                    print(data.count)
                                    let osType: OSType = (message["osType"] as? OSType)!
                                    let bytesPerRow: Int = (message["bytesPerRow"] as? Int)!
                                    let width: Int = (message["width"] as? Int)!
                                    let height: Int = (message["height"] as? Int)!
//                                    print("\(width) \(height) \(width * height * 4) \(osType)")

                                    // 创建 CVPixelBuffer 的属性字典
                                    let options: [String: Any] = [
                                        kCVPixelBufferCGImageCompatibilityKey as String: true,
                                        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
                                        kCVPixelBufferWidthKey as String: width,
                                        kCVPixelBufferHeightKey as String: height
                                    ]

                                    // 创建 CVPixelBuffer
                                    var pixelBuffer: CVPixelBuffer?
                                    let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                                                     width,
                                                                     height,
                                                                     osType,
                                                                     options as CFDictionary,
                                                                     &pixelBuffer)

                                    if status == kCVReturnSuccess, let pixelBuffer = pixelBuffer {
                                        // 锁定像素缓冲区的基地址
                                        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)

                                        // 获取像素缓冲区的基地址
                                        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
                                            // 将 Data 中的字节数据复制到像素缓冲区中
                                            data.copyBytes(to: baseAddress.bindMemory(to: UInt8.self, capacity: bytesPerRow * height), count: data.count)

                                            // 解锁像素缓冲区
                                            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

                                            // 现在 pixelBuffer 包含了从 Data 创建的图像数据
                                        }
                                    }
                                    if let pixelBuffer1 = pixelBuffer {
                                        let ciImage = CIImage(cvPixelBuffer: pixelBuffer1)
                                        let context = CIContext(options: nil)
                                        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
                                        let data:Data = self.CGImageRef2pixelBRGA(imageRef: cgImage!)
                                        resultcb(data)
                                    }
                                    

//                                    let unsafeMutableRawPointer = data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) -> UnsafeMutableRawPointer in
//
//                                            return ptr.baseAddress!
//                                        }
//
//                                    var pixelBuffer: CVPixelBuffer?
//                                    let status = CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
//                                                                              width,
//                                                                              height,
//                                                                              osType,
//                                                                              unsafeMutableRawPointer,
//                                                                              width * 4,
//                                                                              nil,
//                                                                              nil,
//                                                                              options as CFDictionary,
//                                                                              &pixelBuffer)
//
//                                    if status == kCVReturnSuccess, let pixelBuffer = pixelBuffer {
//                                        // 现在 pixelBuffer 包含了从 UnsafeMutableRawPointer 创建的图像数据
//                                        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
//                                        let context = CIContext(options: nil)
//                                        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
//                                        let data:Data = self.CGImageRef2pixelBRGA(imageRef: cgImage!)
//                                        resultcb(data)
//                                    }
                                    
                                    
//                                    print(osType)
                                    return
                                    
                                }
                                resultcb(data)
                            }
                            return
                        }
                        if resultId == -1 {
                            print(message["msg"]!)
                            return
                        }
                        if resultId == 0 {
                            self.isStartCapture = false
                            return
                        }
                        if let resultcb = SwiftFlutterScreenRecordingPlugin.instance?.flutterResults[resultId] {
                            SwiftFlutterScreenRecordingPlugin.instance?.flutterResults.removeValue(forKey: resultId)
                            if let resultArgs = message["resultArgs"]{
                                resultcb(resultArgs)
                                return
                            }
                        }
                    } else {
                        self.isStartCapture = true
                        SwiftFlutterScreenRecordingPlugin.instance?.myResult?(message["resultArgs"] ?? true)
                        SwiftFlutterScreenRecordingPlugin.instance?.myResult = nil
                    }
                }
            })
            result(true)
        }
        else if (call.method == "isScreenOn") {
            if(self.isStartCapture) {
                result(true)
            } else {
                result(false)
            }
        }
        else if (call.method == "addFlutterMethodChannel") {
            let args = call.arguments as? Dictionary<String, Any>
            let channelName = args!["channelName"] as? String
            callFlutterChannels[channelName!] = FlutterMethodChannel(name: channelName!, binaryMessenger: registrar!.messenger())
        }
        else if (call.method == "callFlutterMethod") {
            let args = call.arguments as? Dictionary<String, Any>
            let channelName = args!["channelName"] as? String
            let method = args!["method"] as? String
            let call_args = args!["args"]
            callFlutterChannels[channelName!]?.invokeMethod(method!, arguments: call_args){ (resultFromCb) in
                result(resultFromCb)
            }
        }
        else {
            result(false)
        }


    }

    func launchReplayKitBroadcast(extensionName: String, setupInfo: Dictionary<String, Any>) {
        if #available(iOS 12.0, *) {
            let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 100, y: 100, width: 44, height: 44))
            picker.preferredExtension = extensionName;
            picker.showsMicrophoneButton = false;
            for subView:UIView in picker.subviews {
//                if (subView isMemberOfClass:[UIButton class]]) {
                if subView.isKind(of: UIButton.self) {
                    var button:UIButton = subView as! UIButton;
                    button.sendActions(for: [.touchUpInside, .touchDown]);
                }
            }
//            if let viewController = UIApplication.shared.keyWindow?.rootViewController {
//                viewController.view.addSubview(picker)
//                myResult!(true) // Indicates success
//            } else {
//                myResult!(false)
//            }
        } else {
            // Fallback on earlier versions
            myResult?(false)
            myResult = nil
            return
        }
    }
    func cmSampleBuffer2CGImageRef (cmSampleBuffer: CMSampleBuffer) -> CGImage?{
        if let imageBuffer = CMSampleBufferGetImageBuffer(cmSampleBuffer) {
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            let context = CIContext(options: nil)
            let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
            return cgImage

        }
        return nil
//            guard let pixelBuffer = CMSampleBufferGetImageBuffer(cmSampleBuffer) else {return nil}
//
//            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
//
//            let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
//            let width = CVPixelBufferGetWidth(pixelBuffer)
//            let height = CVPixelBufferGetHeight(pixelBuffer)
//            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
//            let colorSpace = CGColorSpaceCreateDeviceRGB()
//
//            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue|CGBitmapInfo.byteOrder32Little.rawValue)
//        guard let context = CGContext(data: baseAddress, width: width, height:height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
//                CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
//                return nil
//
//            }
//
//            guard let cgImage = context.makeImage() else {return nil}
//            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
//
//            return cgImage
        }

    func CGImageRef2pixelBRGA(imageRef: CGImage) -> Data {
        let width = imageRef.width
        let height = imageRef.height
        let bytesPerPixel = 4;
        let bytesPerRow = bytesPerPixel * width;
        let bitsPerComponent = 8;
        let imageBytes = UnsafeMutableRawPointer.allocate(byteCount: bytesPerRow * height, alignment: MemoryLayout<UInt8>.alignment)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
//        var context = CGContext(data: imageBytes, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue)
        var context = CGContext(data: imageBytes, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedFirst.rawValue)
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context?.draw(imageRef, in:rect)
//        CGColorSpaceRelease(colorSpace)
//        CGContextRelease(context)
//        CGImageRelease(imageRef)
        let data = Data(bytes: imageBytes, count:bytesPerRow * height)
        return data
    }
    @objc func startCaptureScreen() {
        if #available(iOS 11.0, *) {
            RPScreenRecorder.shared().isMicrophoneEnabled=false;
            RPScreenRecorder.shared().isCameraEnabled=false;
            RPScreenRecorder.shared().startCapture(
                handler: { [self] (cmSampleBuffer, rpSampleType, error) in
                guard error == nil else {
                    print("Error starting capture");
                    self.myResult?(false)
                    self.myResult = nil
                    return;
                }

                switch rpSampleType {
                    case RPSampleBufferType.video:
//                         print("writing sample....");
                        if(!self.isStartCapture) {
                            self.isStartCapture = true;
                            self.myResult?(true)
                            self.myResult = nil
                            self.captureWait = 0
                        }


                        let currentTime = Date().timeIntervalSince1970
                        if(self.captureWait > currentTime ) {
                            return
                        }
//                        print("writing sample....11111@@");
//                        print("sample size",  cmSampleBuffer.isValid, cmSampleBuffer.dataBuffer?.dataLength, cmSampleBuffer.imageBuffer);
                        self.captureWait = currentTime + self.captureInterval
                        sampleBufferCache.append(cmSampleBuffer)
                        
//                        let image = cmSampleBuffer2CGImageRef(cmSampleBuffer: cmSampleBuffer);
//                        let data = CGImageRef2pixelBRGA(imageRef: image!)
//                        sampleBufferCache.append(data);
                        while sampleBufferCache.count > maxCacheSize {
                            sampleBufferCache.removeFirst()
                        }
//                        if let imageBuffer = CMSampleBufferGetImageBuffer(cmSampleBuffer) {
//
//                            var pixformat = CVPixelBufferGetPixelFormatType(imageBuffer)
//
////                            let data1 = Data(bytes: &pixformat, count: MemoryLayout<FourCharCode>.size)
////                            if let sss = CFStringCreateWithCString(nil, (data1 as NSData).bytes.bindMemory(to: CChar.self, capacity: data1.count), CFStringEncoding(kCFStringEncodingASCII)) {
////                                print("@@@@~~~~~~ ", sss)
////                            }
////
////                            CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
////
////                            let pixelWidth = CVPixelBufferGetWidth(imageBuffer)
////                            let pixelHeight = CVPixelBufferGetHeight(imageBuffer)
////
////                            let yBytesperrow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0)
////                            let uvbytesperrow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1)
////                            let yPlaneSize = yBytesperrow * pixelHeight
////                            let uvPlaneSize = uvbytesperrow * pixelHeight / 2
////                            guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0),
////                                  let uvBaseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1) else {
////                                return
////                            }
////                            let yData = baseAddress.assumingMemoryBound(to: UInt8.self)
////                            let uvData = uvBaseAddress.assumingMemoryBound(to: UInt8.self)
////
////                            let yBytes = UnsafeMutableBufferPointer(start: yData, count: yPlaneSize)
////                            let uvBytes = UnsafeMutableBufferPointer(start: uvData, count: uvPlaneSize)
////
////                            var yuvBytes = [UInt8](repeating: 0, count: yPlaneSize + uvPlaneSize)
////
////                            yuvBytes.withUnsafeMutableBufferPointer {
////                                yuvBuffer in memcpy(yuvBuffer.baseAddress, yBytes.baseAddress, yPlaneSize)
////                            }
////
////                            yuvBytes.withUnsafeMutableBufferPointer{
////                                yuvBuffer in memcpy(yuvBuffer.baseAddress?.advanced(by: yPlaneSize), uvBytes.baseAddress, uvPlaneSize)
////                            }
////                            let pixelWidth = CVPixelBufferGetWidth(imageBuffer)
////                            let pixelHeight = CVPixelBufferGetHeight(imageBuffer)
////                            let y_size = pixelWidth * pixelHeight;
////                            let uv_size = y_size/2;
////                            let yuv_frame = UnsafeMutableRawPointer.allocate(byteCount: y_size + uv_size, alignment: MemoryLayout<UInt8>.alignment)
////                            let y_frame = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
////                            memcpy(yuv_frame, y_frame, y_size)
////                            let uv_frame = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1)
////                            memcpy(yuv_frame + y_size, uv_frame, uv_size)
////                            let data = Data(bytes: yuvBytes, count:yPlaneSize + uvPlaneSize)
////                            sampleBufferCache.append(data);
////                            while sampleBufferCache.count > maxCacheSize {
////                                sampleBufferCache.removeFirst()
////                            }
////                            yuv_frame.initializeMemory(as: UInt8.self, repeating: 0, count: y_size + uv_size)
////                            if let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) {
////                                let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
////                                let height = CVPixelBufferGetHeight(imageBuffer)
////                                let totalBytes = bytesPerRow * height
////                                let bufferPoint = baseAddress.assumingMemoryBound(to: UInt8.self)
//////                                let formatDesc = CMSampleBufferGetFormatDescription(cmSampleBuffer)
//////                                let pixelFormat = CMFormatDescriptionGetMediaSubType(formatDesc!)
//////                                print("pixelFormat", pixelFormat)
//////                                switch pixelFormat {
//////                                case kCVPixelFormatType_422YpCbCr16BiPlanarVideoRange:
//////                                    print("kCVPixelFormatType_422YpCbCr16BiPlanarVideoRange")
//////                                case kCVPixelFormatType_444YpCbCr16BiPlanarVideoRange:
//////                                    print("kCVPixelFormatType_444YpCbCr16BiPlanarVideoRange")
//////                                case
//////                                kCVPixelFormatType_444YpCbCr16VideoRange_16A_TriPlanar:
//////                                    print("kCVPixelFormatType_444YpCbCr16VideoRange_16A_TriPlanar")
//////
//////
//////                                case
//////                                kCVPixelFormatType_Lossless_420YpCbCr8BiPlanarVideoRange:
//////                                    print("kCVPixelFormatType_Lossless_420YpCbCr8BiPlanarVideoRange")
//////
//////                                case
//////                                kCVPixelFormatType_Lossless_420YpCbCr10PackedBiPlanarVideoRange:
//////                                    print("kCVPixelFormatType_Lossless_420YpCbCr10PackedBiPlanarVideoRange")
//////
//////                                case
//////                                kCVPixelFormatType_Lossless_422YpCbCr10PackedBiPlanarVideoRange:
//////                                    print("kCVPixelFormatType_Lossless_422YpCbCr10PackedBiPlanarVideoRange")
//////
//////
//////
//////                                case
//////                                kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
//////                                    print("kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange")
//////                                case
//////                                kCVPixelFormatType_422YpCbCr8BiPlanarVideoRange:
//////                                    print("kCVPixelFormatType_422YpCbCr8BiPlanarVideoRange")
//////                                case
//////                                kCVPixelFormatType_444YpCbCr8BiPlanarVideoRange:
//////                                    print("kCVPixelFormatType_444YpCbCr8BiPlanarVideoRange")
//////
//////
//////
//////                                case
//////                                kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange:
//////                                    print("kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange")
//////                                case
//////                                kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange:
//////                                    print("kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange")
//////                                case
//////                                kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange:
//////                                    print("kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange")
//////                                default:
//////                                    print("1111")
//////                                }
////                                print("image: ", bytesPerRow, height, totalBytes, CVPixelBufferGetWidth(imageBuffer))
////                                let data = Data(bytes: bufferPoint, count :totalBytes)
////                                sampleBufferCache.append(data);
////                                while sampleBufferCache.count > maxCacheSize {
////                                    sampleBufferCache.removeFirst()
////                                }
////                                // print("success ")
////                            }
//                            CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
//                        }
////                        if let blockBuffer = CMSampleBufferGetDataBuffer(cmSampleBuffer) {
////                            print("writing sample....222222");
////                            var dataPointer: UnsafeMutablePointer<Int8>?
////                            var length = 0
////                            CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)
////
////                            if let dataPointer = dataPointer {
////                                let data = Data(bytes: dataPointer, count: length)
////                                sampleBufferCache.append(data)
////                                print("writing sample....333333");
////                                while sampleBufferCache.count > maxCacheSize {
////                                    sampleBufferCache.removeFirst()
////                                }
////                            }
////                        }
                    default:
                        return;
                    // print("not a video sample, so ignore");
                }
            } ){(error) in
                guard error == nil else {
                    print("Screen record not allowed");
                    self.myResult?(false)
                    self.myResult = nil
                    return;
                }
            }
        } else {
            //Fallback on earlier versions
        }
    }


    @objc func stopCaptureScreen() {
        if (!self.isStartCapture) {
            self.myResult?(true)
            self.myResult = nil
            return
        }
        if #available(iOS 11.0, *) {
            RPScreenRecorder.shared().stopCapture( handler: { (error) in
                print("stopping recording");
                self.isStartCapture = false
                self.captureWait = 0
                self.sampleBufferCache.removeAll()
                self.myResult?(true)
                self.myResult = nil
            })
        } else {
          //  Fallback on earlier versions
            self.myResult?(true)
            self.myResult = nil
        }
    }

    @objc func acquireNextImage() {
        while sampleBufferCache.count > 0 {
           let cmSampleBuffer = sampleBufferCache.removeFirst()
            
            let image = cmSampleBuffer2CGImageRef(cmSampleBuffer: cmSampleBuffer);
            let data = CGImageRef2pixelBRGA(imageRef: image!)
           self.myResult?(data)
           self.myResult = nil
           return
       }
       self.myResult?(nil)
       self.myResult = nil
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
            
            var codec = AVVideoCodecType.jpeg;
            
            if(recordAudio){
                codec = AVVideoCodecType.h264;
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
                    self.myResult?(false)
                    self.myResult = nil
                    return;
                }

                switch rpSampleType {
                case RPSampleBufferType.video:
                    print("writing sample....");
                    if self.videoWriter?.status == AVAssetWriter.Status.unknown {

                        if (( self.videoWriter?.startWriting ) != nil) {
                            print("Starting writing");
                            self.myResult?(true)
                            self.myResult = nil
                            self.videoWriter?.startWriting()
                            self.videoWriter?.startSession(atSourceTime:  CMSampleBufferGetPresentationTimeStamp(cmSampleBuffer))
                        }
                    }

                    if self.videoWriter?.status == AVAssetWriter.Status.writing {
                        if (self.videoWriterInput?.isReadyForMoreMediaData == true) {
                            print("Writting a sample");
                            if  self.videoWriterInput?.append(cmSampleBuffer) == false {
                                print(" we have a problem writing video")
                                self.myResult?(false)
                                self.myResult = nil
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
                           self.myResult?(false)
                           self.myResult = nil
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
              
