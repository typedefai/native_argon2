import 'dart:async';
import 'dart:developer';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'native_argon2_bindings_generated.dart';

const String _libName = 'native_argon2';

class Argon2LibraryLoader {
  static Argon2LibraryLoader instance = Argon2LibraryLoader();

  String? _customLibraryPath;

  void configure({String? libraryPath}) {
    _customLibraryPath = libraryPath;
  }

  DynamicLibrary load() {
    if (_customLibraryPath != null) {
      log('Loading library from custom path: $_customLibraryPath');
      return DynamicLibrary.open(_customLibraryPath!);
    }

    if (Platform.isMacOS || Platform.isIOS) {
      return DynamicLibrary.open('$_libName.framework/$_libName');
    }
    if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open('lib$_libName.so');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('$_libName.dll');
    }
    throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
  }
}

class NativeArgon2 {
  final DynamicLibrary dylib;
  late final NativeArgon2Bindings bindings;

  int _nextRequestId = 0;
  final Map<int, Completer<dynamic>> _requests = {};

  SendPort? _helperIsolateSendPort;
  Completer<SendPort>? _isolateCompleter;

  NativeArgon2({DynamicLibrary? overrideDylib})
    : dylib = overrideDylib ?? Argon2LibraryLoader.instance.load() {
    bindings = NativeArgon2Bindings(dylib);
  }

  Future<SendPort> _getHelperIsolateSendPort() async {
    if (_helperIsolateSendPort != null) {
      return _helperIsolateSendPort!;
    }

    if (_isolateCompleter == null) {
      _isolateCompleter = Completer<SendPort>();
      _initializeHelperIsolate();
    }

    return _isolateCompleter!.future;
  }

  void _initializeHelperIsolate() {
    final receivePort = ReceivePort();
    receivePort.listen((dynamic data) {
      if (data is SendPort) {
        _helperIsolateSendPort = data;
        _isolateCompleter!.complete(data);
        return;
      } else if (data is _Argon2HashResponse) {
        final completer = _requests[data.id];
        if (completer != null) {
          _requests.remove(data.id);
          completer.complete(data);
        }
        return;
      }

      throw UnsupportedError('Unsupported message: ${data.runtimeType}');
    });

    // Pass the current library configuration to the isolate
    final customLibPath = Argon2LibraryLoader.instance._customLibraryPath;

    // Start the helper isolate with configuration
    Isolate.spawn(
      _isolateMain,
      _IsolateSetup(receivePort.sendPort, customLibPath),
    );
  }

  static void _isolateMain(_IsolateSetup setup) {
    final receivePort = ReceivePort();
    if (setup.customLibraryPath != null) {
      Argon2LibraryLoader.instance.configure(
        libraryPath: setup.customLibraryPath,
      );
    }

    final dylib = Argon2LibraryLoader.instance.load();
    final bindings = NativeArgon2Bindings(dylib);

    receivePort.listen((dynamic data) {
      if (data is _Argon2EncodedRequest) {
        final result = _argon2HashEncodedByType(
          data.type,
          bindings,
          data.params,
        );

        setup.sendPort.send(_Argon2HashResponse(data.id, result));
      } else if (data is _Argon2RawRequest) {
        final result = _argon2HashRawByType(data.type, bindings, data.params);

        setup.sendPort.send(_Argon2HashResponse(data.id, result));
      } else {
        throw UnsupportedError('Unsupported message: ${data.runtimeType}');
      }
    });

    setup.sendPort.send(receivePort.sendPort);
  }

  int argon2iHashRaw(Argon2RawParams params) {
    return _argon2HashRawByType(Argon2_type.Argon2_i, bindings, params);
  }

  int argon2dHashRaw(Argon2RawParams params) {
    return _argon2HashRawByType(Argon2_type.Argon2_d, bindings, params);
  }

  int argon2idHashRaw(Argon2RawParams params) {
    return _argon2HashRawByType(Argon2_type.Argon2_id, bindings, params);
  }

  Future<int> argon2iHashRawAsync(Argon2RawParams params) async {
    return _argon2HashRawAsync(Argon2_type.Argon2_i, params);
  }

  Future<int> argon2dHashRawAsync(Argon2RawParams params) async {
    return _argon2HashRawAsync(Argon2_type.Argon2_d, params);
  }

  Future<int> argon2idHashRawAsync(Argon2RawParams params) async {
    return _argon2HashRawAsync(Argon2_type.Argon2_id, params);
  }

  int argon2iHashEncoded(Argon2EncodedParams params) {
    return _argon2HashEncodedByType(Argon2_type.Argon2_i, bindings, params);
  }

  int argon2dHashEncoded(Argon2EncodedParams params) {
    return _argon2HashEncodedByType(Argon2_type.Argon2_d, bindings, params);
  }

  int argon2idHashEncoded(Argon2EncodedParams params) {
    return _argon2HashEncodedByType(Argon2_type.Argon2_id, bindings, params);
  }

  Future<int> argon2iHashEncodedAsync(Argon2EncodedParams params) async {
    return _argon2HashEncodedAsync(Argon2_type.Argon2_i, params);
  }

  Future<int> argon2dHashEncodedAsync(Argon2EncodedParams params) async {
    return _argon2HashEncodedAsync(Argon2_type.Argon2_d, params);
  }

  Future<int> argon2idHashEncodedAsync(Argon2EncodedParams params) async {
    return _argon2HashEncodedAsync(Argon2_type.Argon2_id, params);
  }

  Future<int> _argon2HashEncodedAsync(
    Argon2_type type,
    Argon2EncodedParams params,
  ) async {
    final sendPort = await _getHelperIsolateSendPort();
    final requestId = _nextRequestId++;
    final completer = Completer<_Argon2HashResponse>();
    _requests[requestId] = completer;

    sendPort.send(_Argon2EncodedRequest(requestId, type, params));

    final result = await completer.future;
    return result.result;
  }

  Future<int> _argon2HashRawAsync(
    Argon2_type type,
    Argon2RawParams params,
  ) async {
    final sendPort = await _getHelperIsolateSendPort();
    final requestId = _nextRequestId++;
    final completer = Completer<_Argon2HashResponse>();
    _requests[requestId] = completer;

    sendPort.send(_Argon2RawRequest(requestId, type, params));

    final result = await completer.future;
    return result.result;
  }
}

/// Configuration data for setting up the helper isolate
class _IsolateSetup {
  final SendPort sendPort;
  final String? customLibraryPath;

  const _IsolateSetup(this.sendPort, this.customLibraryPath);
}

class _Argon2EncodedRequest {
  final int id;
  final Argon2_type type;
  final Argon2EncodedParams params;

  _Argon2EncodedRequest(this.id, this.type, this.params);
}

class _Argon2RawRequest {
  final int id;
  final Argon2_type type;
  final Argon2RawParams params;

  _Argon2RawRequest(this.id, this.type, this.params);
}

class _Argon2HashResponse {
  final int id;
  final int result;

  _Argon2HashResponse(this.id, this.result);
}

class Argon2EncodedParams {
  final int tCost;
  final int mCost;
  final int parallelism;
  final Uint8List password;
  final Uint8List salt;
  final int hashLen;
  final Pointer<Char> encoded;
  final int encodedLen;

  Argon2EncodedParams({
    this.tCost = 3,
    this.mCost = 12,
    this.parallelism = 1,
    required this.password,
    required this.salt,
    this.hashLen = 32,
    required this.encoded,
    required this.encodedLen,
  });
}

typedef _Argon2HashEncodedFunction =
    int Function(
      int tCost,
      int mCost,
      int parallelism,
      Pointer<Void> pwd,
      int pwdlen,
      Pointer<Void> salt,
      int saltlen,
      int hashlen,
      Pointer<Char> encoded,
      int encodedlen,
    );

int _argon2HashEncodedByType(
  Argon2_type type,
  NativeArgon2Bindings bindings,
  Argon2EncodedParams params,
) {
  switch (type) {
    case Argon2_type.Argon2_d:
      return _argon2HashEncoded(bindings.argon2d_hash_encoded, params);
    case Argon2_type.Argon2_i:
      return _argon2HashEncoded(bindings.argon2i_hash_encoded, params);
    case Argon2_type.Argon2_id:
      return _argon2HashEncoded(bindings.argon2id_hash_encoded, params);
  }
}

int _argon2HashEncoded(
  _Argon2HashEncodedFunction encodeFunction,
  Argon2EncodedParams params,
) {
  final pwdPtr = calloc<Uint8>(params.password.length);
  final saltPtr = calloc<Uint8>(params.salt.length);

  try {
    pwdPtr.asTypedList(params.password.length).setAll(0, params.password);
    saltPtr.asTypedList(params.salt.length).setAll(0, params.salt);

    final result = encodeFunction(
      params.tCost,
      params.mCost,
      params.parallelism,
      pwdPtr.cast<Void>(),
      params.password.length,
      saltPtr.cast<Void>(),
      params.salt.length,
      params.hashLen,
      params.encoded,
      params.encodedLen,
    );
    return result;
  } finally {
    calloc.free(pwdPtr);
    calloc.free(saltPtr);
  }
}

class Argon2RawParams {
  final int tCost;
  final int mCost;
  final int parallelism;
  final Uint8List password;
  final Uint8List salt;
  final Pointer<Void> hash;
  final int hashLen;

  Argon2RawParams({
    this.tCost = 3,
    this.mCost = 12,
    this.parallelism = 1,
    required this.password,
    required this.salt,
    this.hashLen = 32,
    required this.hash,
  });
}

typedef _Argon2HashRawFunction =
    int Function(
      int tCost,
      int mCost,
      int parallelism,
      Pointer<Void> pwd,
      int pwdlen,
      Pointer<Void> salt,
      int saltlen,
      Pointer<Void> hash,
      int hashlen,
    );

int _argon2HashRaw(
  _Argon2HashRawFunction hashFunction,
  Argon2RawParams params,
) {
  final pwdPtr = calloc<Uint8>(params.password.length);
  final saltPtr = calloc<Uint8>(params.salt.length);

  try {
    pwdPtr.asTypedList(params.password.length).setAll(0, params.password);
    saltPtr.asTypedList(params.salt.length).setAll(0, params.salt);

    final result = hashFunction(
      params.tCost,
      params.mCost,
      params.parallelism,
      pwdPtr.cast<Void>(),
      params.password.length,
      saltPtr.cast<Void>(),
      params.salt.length,
      params.hash,
      params.hashLen,
    );
    return result;
  } finally {
    calloc.free(pwdPtr);
    calloc.free(saltPtr);
  }
}

int _argon2HashRawByType(
  Argon2_type type,
  NativeArgon2Bindings bindings,
  Argon2RawParams params,
) {
  switch (type) {
    case Argon2_type.Argon2_d:
      return _argon2HashRaw(bindings.argon2d_hash_raw, params);
    case Argon2_type.Argon2_i:
      return _argon2HashRaw(bindings.argon2i_hash_raw, params);
    case Argon2_type.Argon2_id:
      return _argon2HashRaw(bindings.argon2id_hash_raw, params);
  }
}
