import 'package:flutter/services.dart';

typedef DeferredLoadcallbackHandler<T> = Future<T> Function(MethodCall call);

class HotFix {
  static const MethodChannel _channel = MethodChannel('hot_fix');

  static void setDeferredHandler<T>(DeferredLoadcallbackHandler<T>? handler) {
    _channel.setMethodCallHandler(handler);
  }
}
