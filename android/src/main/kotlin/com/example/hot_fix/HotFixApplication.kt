package com.example.hot_fix

import android.app.Application
import android.content.Context
import android.util.Log
//import dalvik.system.DexClassLoader
import java.io.File


open class HotFixApplication : Application() {
  companion object {
    const val TAG = "HotFixApplication"
  }

  override fun onCreate() {
    super.onCreate()
    val fix = FixBugUtils(this)

    val dir = filesDir.absolutePath
    val stamp = File("$dir${File.separator}classes.dex.stamp")
    val path = "$dir${File.separator}classes.dex"
    val savePath = "$dir${File.separator}classes_save.dex"
    val appSoPath = "$dir${File.separator}libapp.so"
    val appSoPathTemp = "$dir${File.separator}libapp.so.temp"
    val saveFile = File(savePath)
    val patch = File(path)
    val appPatch = File(appSoPath)
    // 只有标记可用时，才能更新
    if (stamp.exists()) {
      // 在更新 dex 时，libapp.so 也应该同时更新，否则忽略
      if (patch.exists() && appPatch.exists() && !File(appSoPathTemp).exists()) {
        patch.renameTo(saveFile)
        // patch dex 路径已更改，删掉标记文件
        stamp.delete()
      }
    }
    if (saveFile.exists())
      fix.addDex(savePath)
    fix.loadFixDex()
    Log.i(
      TAG, "$dir $stamp, $savePath, $appSoPath ${saveFile.exists()}, ${patch.exists()}"
    )
    ApplicationDelegate.onCreate(this)
  }
}