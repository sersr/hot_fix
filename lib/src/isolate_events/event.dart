import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:dio/dio.dart';

import 'package:nop_db/nop_db.dart';
import 'package:path/path.dart' as path;
import 'package:useful_tools/useful_tools.dart';


import '../hot_fix_channels.dart';
import 'events.dart';

class DeferredMain extends DeferredLoadEventsMessagerMain
    with SendEventPortMixin {
  DeferredMain({
    required this.versionName,
    required this.versionNumber,
    required this.baseUrl,
  });
  final String versionName;
  final int versionNumber;
  final String baseUrl;
  @override
  SendEvent get sendEvent => this;
  @override
  void send(message) {
    Log.w('send mesage $message', onlyDebug: false);
    if (_sendPort != null) {
      _sendPort!.send(message);
    }
  }

  Isolate? _isolate;
  SendPort? _sendPort;

  @override
  void dispose() {
    super.dispose();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }

  Future<void> initState() async {
    final rec = ReceivePort();
    _isolate = await Isolate.spawn(
        _isolateEvent, [rec.sendPort, versionName, versionNumber, baseUrl]);

    _sendPort = await rec.first;

    HotFix.setDeferredHandler((call) async {
      final args = call.arguments;
      switch (call.method) {
        case "loadLibrary":
          Log.w('loadLibrary $args', onlyDebug: false);
          if (args is Map) {
            return loadLibrary(args.cast());
          }
          break;
        case "init":
          Log.i('deferred init', onlyDebug: false);
          if (args is Map) {
            await init(args.cast());
          }
          break;
        default:
          Log.i("not Implemented... ${call.method}",
              onlyDebug: false, showPath: false);
      }
    });
  }
}

Future<void> _isolateEvent(List args) async {
  final rec = ReceivePort();
  final sendport = args[0] as SendPort;
  final versionName = args[1] as String;
  final versionNumber = args[2] as int;
  final baseUrl = args[3] as String;
  final def = DeferredIsolateMain(rec.sendPort, versionName, versionNumber,
      baseUrl: baseUrl);

  rec.listen((message) {
    Log.i('appSO: message: $message');
    if (def.resolve(message)) return;
  });

  sendport.send(rec.sendPort);
}

class DeferredIsolateMain extends DeferredLoadEventsResolveMain {
  DeferredIsolateMain(
    this.sp,
    this.versionName,
    this.versionNumber, {
    required this.baseUrl,
    this.appName = 'libapp.so',
  });

  final String versionName;
  final int versionNumber;

  @override
  SendPort sp;
  // ./files
  // e.g.: files/deferred_libs
  late final String localUnitPath = path.join(appBasePath, 'deferred_libs');
  //e.g.: files/deferred_libs/1.0.0/3/
  late String currentVersionDeferredPath =
      path.join(localUnitPath, versionName, '$versionNumber');

  String baseUrl;
  String appName;

  getUrl(String name) => '$baseUrl$name';

  /// [init]
  String abi = '';
  String appBasePath = '';

  // late final http = HttpClient();
  late final dio = Dio(BaseOptions(
      sendTimeout: 5000,
      receiveDataWhenStatusError: true,
      connectTimeout: 5000));

  Completer<void>? _initTask = Completer<void>();

  bool _done = false;

  @override
  Future<void> init(Map<Object, Object?> data) async {
    final _appBasePath = data['appBasePath'];
    final _abi = data['abi'];

    if (_appBasePath is String) appBasePath = _appBasePath;
    if (_abi is String) {
      abi = _abi;
    }
    Log.e('$appBasePath | $_appBasePath | $currentVersionDeferredPath',
        onlyDebug: false);
    Log.i('$appBasePath, $abi', onlyDebug: false);
    _initTask?.complete();
    _done = true;
    // await checkUpdate();
  }

  String get localAppSoPath => path.join(appBasePath, appName);

  Future<bool> updateDex() async {
    try {
      final localPath = localAppSoPath;
      final response = await dio.get(getUrl('majorversion.json'));
      final map = response.data ?? '';
      final versions =
          map is Map ? map : jsonDecode(map) as Map<Object, Object?>;
      final newVersionName = versions['versionName'];
      final newVersionNumber = versions['versionNumber'];
      if (newVersionName is String) {
        final local = stringSplitToList(versionName);
        final remote = stringSplitToList(newVersionName);

        final isNew = isNewVersion(local, remote);
        Log.i('$isNew | $map', onlyDebug: false);
        if (isNew) {
          final name = '$newVersionName/$newVersionNumber/$abi/$appName';
          final className = '$newVersionName/$newVersionNumber/classes.dex';

          final appVerify = '$localPath.verify';
          final classPath = path.join(appBasePath, 'classes.dex');
          final classVerify = '$classPath.verify';
          final stampPath = '$classPath.stamp';

          void clearAll() {
            final l = [appVerify, classPath, classVerify, stampPath, localPath];
            for (var path in l) {
              final f = File(path);
              deleteFileIfExists(f);
            }
          }

          // ??????
          final remoteVerify = '';

          clearAll();
          // ???????????????????????????????????????'classes.dex.stamp'?????????????????????
          final appVerifyFile = File(appVerify);
          final any = FutureAny();
          any.add(_getAndWrite(name, appVerify));
          any.add(_getAndWrite(className, classVerify));
          await any.wait;
          bool done = false;
          if (appVerifyFile.existsSync()) {
            final classVerifyFile = File(classVerify);
            if (classVerifyFile.existsSync()) {
              appVerifyFile.renameSync(localPath);
              classVerifyFile.renameSync(classPath);
              final stamp = File(stampPath);
              if (!stamp.existsSync()) {
                stamp.createSync(recursive: true);
              }
              done = true;
            }
          }
          // 'Native'?????????????????????????????????????????????
          // ?????????????????????????????????????????????????????????????????????
          // ???????????????????????????????????????????????????????????????
          if (!done) clearAll();
          final l = File(path.join(appBasePath, 'classes.dex'));
          Log.i(
              'new basePath: $localPath'
              'url:${getUrl(name)}, classes.dex: ${l.path} ${l.existsSync()}',
              onlyDebug: false);
          return true;
        }
      }
    } catch (e) {
      Log.i(': error $e', onlyDebug: false);
    }
    return false;
  }

  List<int> stringSplitToList(String str) {
    return str.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  void deleteFileIfExists(File f) {
    if (f.existsSync()) {
      f.deleteSync(recursive: true);
    }
  }

  /// ????????????????????????????????????????????????????????????[_checkUpdate]
  @override
  Future<bool> checkUpdate() {
    return EventQueue.runTaskOnQueue('hot_fix', _checkUpdate);
  }

  Future<void>? runner() {
    return EventQueue.getQueueRunner('hot_fix');
  }

  Future<bool> _checkUpdate() async {
    final localDir = Directory(localUnitPath);
    if (await localDir.exists()) {
      final dirs = await localDir.list(followLinks: false).toList();
      for (final d in dirs) {
        final s = path.split(d.path);
        if (s.isNotEmpty) {
          if (s.last == versionName) {
            Log.i(':  $s');
            continue;
          }
          Log.i(': delete $s, $versionName');
          await d.delete(recursive: true);
        }
      }
    }
    final baseDir = Directory(appBasePath);
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    Log.i('new $appName updateClass.', onlyDebug: false);
    final updated = await updateDex();
    Log.i('new $appName updateClass end $updated.', onlyDebug: false);
    if (updated) return true;

    try {
      Log.i('new $appName start.', onlyDebug: false);
      // update minVersion
      final minVersionRes =
          await dio.get(getUrl('$versionName/minversion.json'));
      final minMap = minVersionRes.data ?? '';
      Log.i('new $appName ${minMap.runtimeType}', onlyDebug: false);
      final minVersions =
          minMap is Map ? minMap : jsonDecode(minMap) as Map<Object, Object?>;
      final newVersionName = minVersions['versionName'];
      final rawVersionCode = minVersions['versionNumber'];

      final newVersionNumber = int.tryParse('$rawVersionCode');

      Log.i(
          'new $appName $newVersionName, current '
          '$versionNumber, $newVersionNumber',
          onlyDebug: false);
      assert(newVersionName == versionName,
          'local: $versionName, remote: $newVersionName');

      if (newVersionNumber != null && newVersionNumber > versionNumber) {
        final name = '$versionName/$newVersionNumber/$abi/$appName';
        await _getAndWrite(name, localAppSoPath);
        return true;
      }
    } catch (e) {
      Log.i(': error $e', onlyDebug: false);
    }
    return false;
  }

  /// ?????????????????????????????????????????????????????????????????????????????????????????????
  /// ????????????????????????
  Future<void> _getAndWrite(String name, String path,
      [String temp = 'temp']) async {
    final url = getUrl(name);
    Log.w('download dio: $url}', onlyDebug: false, showPath: false);
    RandomAccessFile? tempFile;
    try {
      final data = await dio.get<ResponseBody>(url,
          options: Options(responseType: ResponseType.stream));

      final stream = data.data?.stream;
      if (stream != null) {
        final pathTemp = File('$path.$temp');
        if (!pathTemp.existsSync()) {
          pathTemp.createSync(recursive: true);
        }
        tempFile = pathTemp.openSync(mode: FileMode.write);
        await for (final data in stream) {
          tempFile.writeFromSync(data);
        }
        tempFile.closeSync();
        pathTemp.renameSync(path);
      }
    } catch (e) {
      Log.e('error $e');
      tempFile?.closeSync();
    }
  }

  @override
  Future<Map<String, Object>?> loadLibrary(data) async {
    if (!_done) {
      Log.e('???????????????????????????', onlyDebug: false);
      _initTask ??= Completer<void>();
      await _initTask!.future;
    }
    assert(_done);

    Log.i(': $data');
    final id = data['id'] as int?;
    final componentName = data['componentName'] as String?;
    final abi = data['abi'] as String?;
    Log.i(':2 $data');

    if (id == null || abi == null || componentName == null) {
      return null;
    }
    assert(this.abi.isEmpty || this.abi == abi);
    final name = '$appName-$id.part.so';
    final returnPath = path.join(currentVersionDeferredPath, abi, name);
    if (!File(returnPath).existsSync() ||
        File('$returnPath.temp').existsSync()) {
      try {
        final fullName = '$versionName/$versionNumber/$abi/$name';
        await _getAndWrite(fullName, returnPath);
      } catch (e) {
        Log.i(': $e');
      }
    }
    return {'id': id, 'localPath': returnPath};
  }
}

void writeFile(List<int> bytes, String path, [String temp = 'temp']) {
  final pathTemp = File('$path.$temp');
  if (!pathTemp.existsSync()) {
    pathTemp.createSync(recursive: true);
  }
  final w = File(path);
  if (!w.existsSync()) {
    w.createSync(recursive: true);
  }
  w.writeAsBytesSync(bytes);
  if (pathTemp.existsSync()) {
    pathTemp.deleteSync(recursive: true);
  }
}

void writeFileRename(List<int> bytes, String path, [String temp = 'temp']) {
  final pathTemp = File('$path.$temp');
  if (!pathTemp.existsSync()) {
    pathTemp.createSync(recursive: true);
  }
  pathTemp.writeAsBytesSync(bytes);
  pathTemp.renameSync(path);
}

bool isNewVersion(List<int> local, List<int> remote) {
  final length = local.length;
  if (length == remote.length && length == 3) {
    for (var i = 0; i < length; i++) {
      if (local[i] > remote[i]) {
        return false;
      }
      if (local[i] < remote[i]) {
        return true;
      }
    }
  }
  return false;
}
