package com.example.hot_fix

import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.PersistableBundle
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterJNI
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.io.File

open class HotFixActivity : FlutterActivity() {
  companion object {
    const val TAG = "HotFixActivity"
  }

  override fun provideFlutterEngine(context: Context): FlutterEngine? {
    val nativeDir = context.applicationInfo.nativeLibraryDir
    val basePath = nativeDir + File.separator
//    Log.i(TAG, "Hello world  新版本 1.0.3")

    var abi: String? = null
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      val abis = Build.SUPPORTED_ABIS
      for (a in abis) {
        if (File(basePath + "libapp_stamp_$a.so").exists()) {
          Log.i(TAG, "contains: abi: $a")
          abi = a
          break
        }
      }
    }

    if (abi == null) {
      val abiName = nativeDir.split(File.separator).last()
      abi = Build.CPU_ABI
      Log.i(TAG, "$abiName | $abi ")
    }

    val appBasePath = context.filesDir.path
    val loader = FlutterInjector.instance().flutterLoader()
    val engine = if (loader is NopFlutterLoader) {
      val jni = loader.flutterJNI
      loader.appBasePath = appBasePath
      loader.abi = abi
      FlutterEngine(this, loader, jni)
    } else {
      FlutterEngine(this)
    }

    engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())

    val deferredComponentManager = FlutterInjector.instance().deferredComponentManager()
    if (deferredComponentManager is DeferredLoadNativeDir) {
      val channel = MethodChannel(engine.dartExecutor, "hot_fix")
      deferredComponentManager.setDeferredData(channel, abi!!, appBasePath)
    }
    return engine
  }

}
