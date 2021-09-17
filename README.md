# hot_fix

!! 测试


在Android中，由于flutter使用了`FlutterInjector`，我们可以自定义加载方式，
使用最简单粗暴的方法：全量更新，插入`classes.dex`，更换`libapp.so`.

## 描述

url：`baseUrl`/`versionName`/`versionNumber`/`abi`/`appName`  
比如：`http://192.168.1.127:8080/1.0.0/1/arm64-v8a/libapp.so`

在`baseUrl`下,文件结构：
```
│  majorversion.json
│  
└─1.1.0
    │  minversion.json
    │  
    └─0
        │  classes.dex
        │  classes.dex.sha256
        │  
        ├─arm64-v8a
        │      libapp.so
        │      libapp.so.sha256
        │      
        ├─armeabi-v7a
        │      libapp.so
        │      libapp.so.sha256
        │      
        └─x86_64
                libapp.so
                libapp.so.sha256
```
`versionName` 和 `versionNumber`是`pubspec.yaml`中的`version`信息，  
如：version: 1.0.0+1 versionName = 1.0.0, versionNumber = 1  
`majorversion.json`和`minversion.json`格式一样，
```
{"versionName":"1.1.0","versionNumber":"1"}
```
`majorversion.json`的信息应该是最新版本的信息，更新`classes.dex`和`libapp.so`；`minversion.json`在versionName下，指定当前版本下最新versionNumber版本，只会更新`libapp.so`

### java

继承`HotFixApplication`和`HotFixActivity`:  
```java
class MyApplication extends HotFixApplication {}
class MyActivity extends HotFixActivity {}
```
在`libs`为每一个`abi`创建一个文件：libapp_stamp_$`abi`.so  

### 修改flutter_tools收集所需文件

可以为flutter插入示例补丁：patch/flutter_2.6.0.path 直接生成除了`majorversion.json`所有文件，生成文件在`build/deferred_libs`下，
在 flutter 根目录下：

    git apply path/to/futter_2.6.0.patch

如果无法应用补丁，也可以手动修改`flutter_tools`  
记得要删除cache/flutter_tools.snapshot，会自动重新构建更改的版本

在项目中使用：
```dart
...
import 'package:hot_fix/hot_fix.dart';
...
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android) {
    final hot = DeferredMain(
        versionName: versionName,
        versionNumber: versionNumber,
        baseUrl: 'http://192.168.1.127:8080/shudu/');
    await hot.initState();
  }
  runApp(...);
}
```
