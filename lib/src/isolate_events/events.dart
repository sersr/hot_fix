import 'dart:async';
import 'package:nop_annotations/nop_annotations.dart';
import 'package:nop_db/nop_db.dart';

part 'events.g.dart';

@NopIsolateEvent()
abstract class DeferredLoadEvents {
  DeferredLoadEvents get events => this;
  FutureOr<Map<String, Object>?> loadLibrary(Map<Object, Object?> data);
  FutureOr<void> init(Map<Object, Object?> data);
  FutureOr<void> checkUpdate();
}
