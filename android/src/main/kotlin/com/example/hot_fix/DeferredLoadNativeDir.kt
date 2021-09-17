package com.example.hot_fix

//import io.flutter.Log
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.FlutterJNI
import io.flutter.embedding.engine.deferredcomponents.DeferredComponentManager
import io.flutter.embedding.engine.loader.ApplicationInfoLoader
import io.flutter.embedding.engine.loader.FlutterApplicationInfo
import io.flutter.embedding.engine.systemchannels.DeferredComponentChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.collections.HashMap

class DeferredLoadNativeDir(private var context: Context, private var flutterJNI: FlutterJNI?) :
  DeferredComponentManager {
  companion object {
    const val TAG = "DeferredLoadNativeDir"
  }

  private var channel: DeferredComponentChannel? = null
  private var flutterApplicationInfo: FlutterApplicationInfo = ApplicationInfoLoader.load(context)
  private var defChannel: MethodChannel? = null
  private var paths = HashMap<Int, String>()
  private lateinit var abi: String

  fun setDeferredData(channel: MethodChannel, abi: String, appBasePath: String) {
    this.defChannel = channel
    this.abi = abi
    channel.invokeMethod("init", mapOf(
      "abi" to abi,
      "appBasePath" to appBasePath
    ))
  }

  override fun setJNI(flutterJNI: FlutterJNI?) {
    this.flutterJNI = flutterJNI
  }

  override fun setDeferredComponentChannel(channel: DeferredComponentChannel?) {
    this.channel = channel

  }


  override fun installDeferredComponent(loadingUnitId: Int, componentName: String?) {
    Log.w(TAG, "DeferredLoadNativeDir: $loadingUnitId   abi: ${Build.CPU_ABI} | $abi")
    val exists = paths.containsKey(loadingUnitId) && File(paths[loadingUnitId]!!).exists()

    if (defChannel == null || exists) {
      loadDartLibrary(loadingUnitId, componentName)
      loadAssets(loadingUnitId, componentName)
    } else {
      paths.remove(loadingUnitId)
      val args = mapOf(
        "id" to loadingUnitId,
        "componentName" to (componentName ?: ""),
        "abi" to abi
      )

      val result = object : MethodChannel.Result {
        override fun success(result: Any?) {
          val map = result as Map<*, *>
          val id = map["id"] as Int
          val path = map["localPath"] as String
          val p = File(path)
          val soExists = p.exists()
            Log.i(TAG, "exists: $soExists | $path")
          if (soExists) {
            paths[id] = path
            pathsState[loadingUnitId] = 1
            loadDartLibrary(loadingUnitId, componentName)
          } else {
            pathsState[loadingUnitId] = -3
            flutterJNI!!.deferredComponentInstallFailure(loadingUnitId, "error", true)
          }
        }

        override fun error(errorCode: String?, errorMessage: String?, errorDetails: Any?) {
          pathsState[loadingUnitId] = -2

          loadDartLibrary(loadingUnitId, componentName)
//                    flutterJNI!!.deferredComponentInstallFailure(loadingUnitId, "error", true)
          Log.i(TAG, "error $loadingUnitId")
        }

        override fun notImplemented() {
          pathsState[loadingUnitId] = -1
          flutterJNI!!.deferredComponentInstallFailure(loadingUnitId, "error", true)
          Log.i(TAG, "notImplemented $loadingUnitId")
        }

      }
      pathsState[loadingUnitId] = 0
      defChannel!!.invokeMethod("loadLibrary", args, result)
    }
  }

  val pathsState = mutableMapOf<Int, Int>()
  override fun getDeferredComponentInstallState(
    loadingUnitId: Int,
    componentName: String?
  ): String {
    return "notImplemented"
//        return  paths.containsKey(loadingUnitId).toString()
  }

  override fun loadAssets(loadingUnitId: Int, componentName: String?) {
    Log.i(TAG, "loadAssets: $loadingUnitId, $componentName")
    try {
      context = context.createPackageContext(context.packageName, 0)
      val assetManager = context.assets
      flutterJNI!!.updateJavaAssetManager(
        assetManager,
        flutterApplicationInfo.flutterAssetsDir
      )
    } catch (e: PackageManager.NameNotFoundException) {
      throw RuntimeException(e)
    }
  }

  override fun loadDartLibrary(loadingUnitId: Int, componentName: String?) {
    val nativeDir = flutterApplicationInfo.nativeLibraryDir

    val aotSharedLibraryName =
      flutterApplicationInfo.aotSharedLibraryName + "-" + loadingUnitId + ".part.so"

    val path = "$nativeDir/$aotSharedLibraryName"
    val file = File(path)
    val exists = file.exists()
    Log.i(TAG, " $path exists: $exists, $componentName")
    Log.i(TAG, "${context.filesDir.path}: ${context.filesDir.name}")
    val soPaths = mutableListOf<String>()

    val updatePath = paths[loadingUnitId];
    if (updatePath != null && File(updatePath).exists()) {
      soPaths.add(updatePath);
    }
    if (exists) soPaths.add(path)
    Log.i(TAG, "soPath: $soPaths")

    flutterJNI!!.loadDartDeferredLibrary(loadingUnitId, soPaths.toTypedArray())


  }

  override fun uninstallDeferredComponent(loadingUnitId: Int, componentName: String?): Boolean {
    return true
  }

  override fun destroy() {
    channel = null
    flutterJNI = null
  }

}