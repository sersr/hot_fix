// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'events.dart';

// **************************************************************************
// Generator: IsolateEventGeneratorForAnnotation
// **************************************************************************

enum DeferredLoadEventsMessage { loadLibrary, init, checkUpdate }

abstract class DeferredLoadEventsResolveMain extends DeferredLoadEvents
    with Resolve, DeferredLoadEventsResolve {
  @override
  bool resolve(resolveMessage) {
    if (remove(resolveMessage)) return true;
    if (resolveMessage is! IsolateSendMessage) return false;
    return super.resolve(resolveMessage);
  }
}

abstract class DeferredLoadEventsMessagerMain extends DeferredLoadEvents
    with DeferredLoadEventsMessager {}

mixin DeferredLoadEventsResolve on Resolve, DeferredLoadEvents {
  late final _deferredLoadEventsResolveFuncList =
      List<DynamicCallback>.unmodifiable(
          [_loadLibrary_0, _init_1, _checkUpdate_2]);

  @override
  bool resolve(resolveMessage) {
    if (resolveMessage is IsolateSendMessage) {
      final type = resolveMessage.type;
      if (type is DeferredLoadEventsMessage) {
        dynamic result;
        try {
          result = _deferredLoadEventsResolveFuncList
              .elementAt(type.index)(resolveMessage.args);
          receipt(result, resolveMessage);
        } catch (e) {
          receipt(result, resolveMessage, e);
        }
        return true;
      }
    }
    return super.resolve(resolveMessage);
  }

  FutureOr<Map<String, Object>?> _loadLibrary_0(args) => loadLibrary(args);
  FutureOr<void> _init_1(args) => init(args);
  FutureOr<void> _checkUpdate_2(args) => checkUpdate();
}

/// implements [DeferredLoadEvents]
mixin DeferredLoadEventsMessager {
  SendEvent get sendEvent;

  FutureOr<Map<String, Object>?> loadLibrary(Map<Object, Object?> data) async {
    return sendEvent.sendMessage(DeferredLoadEventsMessage.loadLibrary, data);
  }

  FutureOr<void> init(Map<Object, Object?> data) async {
    return sendEvent.sendMessage(DeferredLoadEventsMessage.init, data);
  }

  FutureOr<void> checkUpdate() async {
    return sendEvent.sendMessage(DeferredLoadEventsMessage.checkUpdate, null);
  }
}
