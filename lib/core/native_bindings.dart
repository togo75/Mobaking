// native_bindings.dart

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

final DynamicLibrary nemoLib =
    Platform.isAndroid
        ? DynamicLibrary.open('libNeMoOnnxSharp.so')
        : throw UnsupportedError("Platform not supported");

// FFI typedefs
typedef InitSessionC =
    Uint64 Function(
      Pointer<Utf8> onnxPath,
      Int32 modelType,
      Pointer<Utf8> vocabulary,
      Pointer<Utf8> extraPaths,
    );
typedef InitSessionDart =
    int Function(Pointer<Utf8>, int, Pointer<Utf8>, Pointer<Utf8>);

typedef TranscribeC =
    Pointer<Utf8> Function(Uint64 handle, Pointer<Utf8> wavPath);
typedef TranscribeDart = Pointer<Utf8> Function(int, Pointer<Utf8>);

typedef FreeCStringC = Void Function(Pointer<Utf8>);
typedef FreeCStringDart = void Function(Pointer<Utf8>);

typedef DisposeC = Void Function(Uint64);
typedef DisposeDart = void Function(int);

// Bind native functions
final InitSessionDart _nativeInitSession =
    nemoLib.lookup<NativeFunction<InitSessionC>>('InitSession').asFunction();

final TranscribeDart transcribe =
    nemoLib.lookup<NativeFunction<TranscribeC>>('Transcribe').asFunction();

final FreeCStringDart freeCString =
    nemoLib.lookup<NativeFunction<FreeCStringC>>('FreeCString').asFunction();

final DisposeDart disposeSession =
    nemoLib.lookup<NativeFunction<DisposeC>>('Dispose').asFunction();

/// Clean wrapper utility to simplify passing collections out to the FFI boundary
int initSession({
  required String mainModelPath,
  required int modelType,
  required List<String> vocabulary,
  List<String> extraModelPaths = const [],
}) {
  final Pointer<Utf8> pathPtr = mainModelPath.toNativeUtf8();
  final Pointer<Utf8> vocabPtr = vocabulary.join('\n').toNativeUtf8();
  final Pointer<Utf8> extraPathsPtr = extraModelPaths.join('\n').toNativeUtf8();

  try {
    return _nativeInitSession(pathPtr, modelType, vocabPtr, extraPathsPtr);
  } finally {
    malloc.free(pathPtr);
    malloc.free(vocabPtr);
    malloc.free(extraPathsPtr);
  }
}
