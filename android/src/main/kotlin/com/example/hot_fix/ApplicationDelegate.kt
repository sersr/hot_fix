package com.example.hot_fix

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
//import android.os.BuildConfig


import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterJNI
import java.util.concurrent.Executors
import java.util.concurrent.ThreadFactory

class ApplicationDelegate {
  private class NamedThreadFactory : ThreadFactory {
    private var threadId = 0
    override fun newThread(command: Runnable): Thread {
      val thread = Thread(command)
      thread.name = "flutter-worker-" + threadId++
      return thread
    }
  }
  companion object {
    private const val TAG = "ApplicationDelegate"

    @SuppressLint("VisibleForTests")
    fun onCreate(applicationContext: Context) {
      Log.e(TAG, "hello  abi: ${Build.CPU_ABI}")
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {

        Log.w(TAG, "abis: ${Build.SUPPORTED_ABIS?.contentToString()}")
      }
      val info = applicationContext.applicationInfo

      Log.w(TAG, "nativeLibraryDir: ${info.nativeLibraryDir}")
      val executorService = Executors.newCachedThreadPool(NamedThreadFactory())
      val fac = FlutterJNI.Factory()
      val jni = fac.provideFlutterJNI()
      val loader = NopFlutterLoader(jni,executorService)

      val injBuilder = FlutterInjector.Builder()
        .setFlutterJNIFactory(fac)
        .setFlutterLoader(loader)

        .setDeferredComponentManager(
          DeferredLoadNativeDir(applicationContext, jni)
        )

      val inj = injBuilder.build()
      FlutterInjector.setInstance(inj)

    }
  }
}