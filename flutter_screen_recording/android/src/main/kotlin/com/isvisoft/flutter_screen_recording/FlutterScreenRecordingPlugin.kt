package com.isvisoft.flutter_screen_recording

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Environment
import android.util.DisplayMetrics
import android.util.Log
import android.view.Display
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat.getSystemService
import android.view.Surface

import android.graphics.Bitmap;
import android.media.Image;
import android.media.ImageReader;
import android.graphics.PixelFormat;

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.PluginRegistry.Registrar

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.io.File
import java.io.IOException

import com.foregroundservice.ForegroundService


class FlutterScreenRecordingPlugin(
        private val registrar: Registrar
) : MethodCallHandler, PluginRegistry.ActivityResultListener{

    var mScreenDensity: Int = 0
    var mMediaRecorder: MediaRecorder? = null
    var mImageReader: ImageReader? = null
    var readyImageCount: Int = 0
    var mProjectionManager: MediaProjectionManager? = null
    var mMediaProjection: MediaProjection? = null
    var mMediaProjectionCallback: MediaProjectionCallback? = null
    var mMediaProjectionForCaptureCallback: MediaProjectionForCaptureCallback? = null
    var mVirtualDisplay: VirtualDisplay? = null
    var mDisplayWidth: Int = 1280
    var mDisplayHeight: Int = 800
    var videoName: String? = ""
    var mFileName: String? = ""
    var recordAudio: Boolean? = false;
    private val SCREEN_RECORD_REQUEST_CODE = 333
    private val SCREEN_RECORD_FOR_CAPTURE_REQUEST_CODE = 666

    private lateinit var _result: MethodChannel.Result


    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "flutter_screen_recording")
            val plugin = FlutterScreenRecordingPlugin(registrar)
            channel.setMethodCallHandler(plugin)
            registrar.addActivityResultListener(plugin)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == SCREEN_RECORD_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                mMediaProjectionCallback = MediaProjectionCallback()
                mMediaProjection = mProjectionManager?.getMediaProjection(resultCode, data!!)
                mMediaProjection?.registerCallback(mMediaProjectionCallback, null)
                mVirtualDisplay = createVirtualDisplay(mMediaRecorder?.surface)
                _result.success(true)
                return true
            } else {
                _result.success(false)
            }
        } else if(requestCode == SCREEN_RECORD_FOR_CAPTURE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                mMediaProjectionForCaptureCallback = MediaProjectionForCaptureCallback()
                mMediaProjection = mProjectionManager?.getMediaProjection(resultCode, data!!)
                mMediaProjection?.registerCallback(mMediaProjectionForCaptureCallback, null)
                mVirtualDisplay = createVirtualDisplay(mImageReader?.getSurface())
                _result.success(true)
                return true
            } else {
                _result.success(false)
            }
        }
        return false
    }

    override fun  onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "startRecordScreen") {
            try {

                _result = result
                ForegroundService.startService(registrar.context(), "Your screen is being recorded")
                mProjectionManager = registrar.context().applicationContext.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager?

                val metrics = DisplayMetrics()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    mMediaRecorder = MediaRecorder(registrar.context().applicationContext)
                } else {
                    @Suppress("DEPRECATION")
                    mMediaRecorder = MediaRecorder()
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val display = registrar.activity()!!.display
                    display?.getRealMetrics(metrics)
                } else {
                    val defaultDisplay = registrar.context().applicationContext.getDisplay()
                    defaultDisplay?.getMetrics(metrics)
                }
                mScreenDensity = metrics.densityDpi
                calculeResolution(metrics)
                videoName = call.argument<String?>("name")
                recordAudio = call.argument<Boolean?>("audio")

                startRecordScreen()

            } catch (e: Exception) {
                println("Error onMethodCall startRecordScreen")
                println(e.message)
                result.success(false)
            }
        } else if (call.method == "startCaptureScreen") {
            try {

                _result = result
                ForegroundService.startService(registrar.context(), "Your screen is being recorded")
                mProjectionManager = registrar.context().applicationContext.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager?

                val metrics = DisplayMetrics()

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val display = registrar.activity()!!.display
                    display?.getRealMetrics(metrics)
                } else {
                    val defaultDisplay = registrar.context().applicationContext.getDisplay()
                    defaultDisplay?.getMetrics(metrics)
                }
                mScreenDensity = metrics.densityDpi
                mImageReader = ImageReader.newInstance(metrics.widthPixels, metrics.heightPixels, PixelFormat.RGBA_8888, 3);
                mImageReader?.setOnImageAvailableListener({ reader ->
                    readyImageCount = readyImageCount.inc();
                }, null)
                calculeResolution(metrics)
                // videoName = call.argument<String?>("name")
                // recordAudio = call.argument<Boolean?>("audio")

                startCaptureScreen()

            } catch (e: Exception) {
                println("Error onMethodCall startRecordScreen")
                println(e.message)
                result.success(false)
            }

        } else if (call.method == "acquireNextImage") {
                if(readyImageCount<=0) {
                    result.success(null);
                    return;
                }
                if(mImageReader==null) {
                    result.success(null);
                    return;
                }
                var image:Image? = mImageReader?.acquireNextImage();
                if(image==null) {
                    result.success(null);
                    return;
                }
                readyImageCount = readyImageCount - 1;
                var width: Int = image.getWidth();
                var height: Int = image.getHeight();

                var planes = image.getPlanes();
                var buffer:ByteBuffer = planes[0].getBuffer();
                var pixelStride: Int = planes[0].getPixelStride();
                var rowStride: Int = planes[0].getRowStride();
                var rowPadding: Int = rowStride - pixelStride * width;

                var bitmap:Bitmap = Bitmap.createBitmap(width+rowPadding/pixelStride, height, Bitmap.Config.ARGB_8888);
                bitmap.copyPixelsFromBuffer(buffer);
                // String filePath = Environment.getExternalStorageDirectory().getPath() + "/hello.jpg";
                //bitmap保存为图片
                // saveBitmap(bitmap, filePath);
                var stream:ByteArrayOutputStream = ByteArrayOutputStream();
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream);
                var imageInByte = stream.toByteArray();
                result.success(imageInByte);
                image.close();
        } else if (call.method == "getReadyImageCount") {
                result.success(readyImageCount);
        } else if (call.method == "stopRecordScreen") {
            try {
                ForegroundService.stopService(registrar.context())
                if (mMediaRecorder != null) {
                    stopRecordScreen()
                    result.success(mFileName)
                } else {
                    result.success("")
                }
            } catch (e: Exception) {
                result.success("")
            }
        } else if (call.method == "stopCaptureScreen") {
            try {
                ForegroundService.stopService(registrar.context())
                if (mImageReader != null) {
                    stopCaptureScreen()
                    result.success(true)
                    return
                } else {
                    result.success(true)
                    return
                }
            } catch (e: Exception) {
                result.success(false)
            }
        }
        else if (call.method == "isScreenOn") {
            try {
                if(mMediaProjection==null || mVirtualDisplay==null) {
                    result.success(false)
                    return
                }
                if(mMediaRecorder!=null || mImageReader!=null) {
                    result.success(true)
                    return
                }
                result.success(false)
            } catch (e: Exception) {
                result.success(false)
            }
        }
        else {
            result.notImplemented()
        }
    }

    private fun calculeResolution(metrics: DisplayMetrics) {

        mDisplayHeight = metrics.heightPixels
        mDisplayWidth = metrics.widthPixels

        var maxRes = 1280.0;
        if (metrics.scaledDensity >= 3.0f) {
            maxRes = 1920.0;
        }
        if (metrics.widthPixels > metrics.heightPixels) {
            var rate = metrics.widthPixels / maxRes

            if(rate > 1.5){
                rate = 1.5
            }
            mDisplayWidth = maxRes.toInt()
            mDisplayHeight = (metrics.heightPixels / rate).toInt()
            println("Rate : $rate")
        } else {
            var rate = metrics.heightPixels / maxRes
            if(rate > 1.5){
                rate = 1.5
            }
            mDisplayHeight = maxRes.toInt()
            mDisplayWidth = (metrics.widthPixels / rate).toInt()
            println("Rate : $rate")
        }

        println("Scaled Density")
        println(metrics.scaledDensity)
        println("Original Resolution ")
        println(metrics.widthPixels.toString() + " x " + metrics.heightPixels)
        println("Calcule Resolution ")
        println("$mDisplayWidth x $mDisplayHeight")
    }

    
    fun startCaptureScreen() {
        // try {
        //     try {
        //         mFileName = registrar.context().getExternalCacheDir()?.getAbsolutePath()
        //         mFileName += "/$videoName.mp4"
        //     } catch (e: IOException) {
        //         println("Error creating name")
        //         return
        //     }
        //     mMediaRecorder?.setVideoSource(MediaRecorder.VideoSource.SURFACE)
        //     if (recordAudio!!) {
        //         mMediaRecorder?.setAudioSource(MediaRecorder.AudioSource.MIC);
        //         mMediaRecorder?.setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP);
        //         mMediaRecorder?.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB);
        //     } else {
        //         mMediaRecorder?.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        //     }
        //     mMediaRecorder?.setOutputFile(mFileName)
        //     mMediaRecorder?.setVideoSize(mDisplayWidth, mDisplayHeight)
        //     mMediaRecorder?.setVideoEncoder(MediaRecorder.VideoEncoder.H264)
        //     mMediaRecorder?.setVideoEncodingBitRate(5 * mDisplayWidth * mDisplayHeight)
        //     mMediaRecorder?.setVideoFrameRate(30)

        //     mMediaRecorder?.prepare()
        //     mMediaRecorder?.start()
        // } catch (e: IOException) {
        //     Log.d("--INIT-RECORDER", e.message+"")
        //     println("Error startRecordScreen")
        //     println(e.message)
        // }
        val permissionIntent = mProjectionManager?.createScreenCaptureIntent()
        ActivityCompat.startActivityForResult(registrar.activity()!!, permissionIntent!!, SCREEN_RECORD_FOR_CAPTURE_REQUEST_CODE, null)
    }

    fun startRecordScreen() {
        try {
            try {
                mFileName = registrar.context().getExternalCacheDir()?.getAbsolutePath()
                mFileName += "/$videoName.mp4"
            } catch (e: IOException) {
                println("Error creating name")
                return
            }
            mMediaRecorder?.setVideoSource(MediaRecorder.VideoSource.SURFACE)
            if (recordAudio!!) {
                mMediaRecorder?.setAudioSource(MediaRecorder.AudioSource.MIC);
                mMediaRecorder?.setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP);
                mMediaRecorder?.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB);
            } else {
                mMediaRecorder?.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            }
            mMediaRecorder?.setOutputFile(mFileName)
            mMediaRecorder?.setVideoSize(mDisplayWidth, mDisplayHeight)
            mMediaRecorder?.setVideoEncoder(MediaRecorder.VideoEncoder.H264)
            mMediaRecorder?.setVideoEncodingBitRate(5 * mDisplayWidth * mDisplayHeight)
            mMediaRecorder?.setVideoFrameRate(30)

            mMediaRecorder?.prepare()
            mMediaRecorder?.start()
        } catch (e: IOException) {
            Log.d("--INIT-RECORDER", e.message+"")
            println("Error startRecordScreen")
            println(e.message)
        }
        val permissionIntent = mProjectionManager?.createScreenCaptureIntent()
        ActivityCompat.startActivityForResult(registrar.activity()!!, permissionIntent!!, SCREEN_RECORD_REQUEST_CODE, null)
    }

    fun stopRecordScreen() {
        try {
            println("stopRecordScreen")
            mMediaRecorder?.stop()
            mMediaRecorder?.reset()
            mMediaRecorder?.release()
            mMediaRecorder = null;
            println("stopRecordScreen success")

        } catch (e: Exception) {
            Log.d("--INIT-RECORDER", e.message +"")
            println("stopRecordScreen error")
            println(e.message)

        } finally {
            stopScreenSharing()
        }
    }

    fun stopCaptureScreen() {
        try {
            println("stopCaptureScreen")
            mImageReader?.close()
            mImageReader = null
            println("stopCaptureScreen success")

        } catch (e: Exception) {
            Log.d("--INIT-RECORDER", e.message +"")
            println("stopCaptureScreen error")
            println(e.message)

        } finally {
            stopScreenCaptureSharing()
        }
    }

    private fun createVirtualDisplay(surface: Surface?): VirtualDisplay? {
        try {
            return mMediaProjection?.createVirtualDisplay(
                "MainActivity", mDisplayWidth, mDisplayHeight, mScreenDensity,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, surface, null, null
            )
        } catch (e: Exception) {
            println("createVirtualDisplay err")
            println(e.message)
            return null
        }
    }

    private fun stopScreenCaptureSharing() {
        if (mVirtualDisplay != null) {
            mVirtualDisplay?.release()
            if (mMediaProjection != null) {
                mMediaProjection?.unregisterCallback(mMediaProjectionForCaptureCallback)
                mMediaProjection?.stop()
                mMediaProjection = null
            }
            Log.d("TAG", "MediaProjection Stopped")
        }
    }

    private fun stopScreenSharing() {
        if (mVirtualDisplay != null) {
            mVirtualDisplay?.release()
            if (mMediaProjection != null) {
                mMediaProjection?.unregisterCallback(mMediaProjectionCallback)
                mMediaProjection?.stop()
                mMediaProjection = null
            }
            Log.d("TAG", "MediaProjection Stopped")
        }
    }

    inner class MediaProjectionCallback : MediaProjection.Callback() {
        override fun onStop() {
            mMediaRecorder?.reset()
            mMediaRecorder?.release()
            mMediaRecorder = null;
            mMediaProjection = null
            stopScreenSharing()
        }
    }

    
    inner class MediaProjectionForCaptureCallback : MediaProjection.Callback() {
        override fun onStop() {
            mImageReader?.close()
            mImageReader = null
            mMediaProjection = null
            stopScreenCaptureSharing()
        }
    }
    
}