import 'dart:async';
import 'dart:js_interop';

import 'photo_picker.dart';

@JS('document')
external _Document get _document;

extension type _Document(JSObject _) implements JSObject {
  external _Input createElement(String tag);
}

extension type _Input(JSObject _) implements JSObject {
  external set type(String value);
  external set accept(String value);
  external _FileList? get files;
  external void click();
  external void addEventListener(String type, JSFunction listener);
}

extension type _FileList(JSObject _) implements JSObject {
  external int get length;
  external _File? item(int index);
}

extension type _File(JSObject _) implements JSObject {
  external String get type;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

const canPickPhoto = true;

Future<PickedPhoto?> pickPhoto() {
  final result = Completer<PickedPhoto?>();
  final input = _document.createElement('input')
    ..type = 'file'
    ..accept = 'image/jpeg,image/png';

  Future<void> read() async {
    try {
      final files = input.files;
      final file = files == null || files.length == 0 ? null : files.item(0);
      if (file == null) {
        result.complete(null);
        return;
      }
      final buffer = await file.arrayBuffer().toDart;
      result.complete(PickedPhoto(buffer.toDart.asUint8List(), file.type));
    } catch (error) {
      result.completeError(error);
    }
  }

  input.addEventListener(
    'change',
    ((JSAny _) {
      if (!result.isCompleted) read();
    }).toJS,
  );
  input.addEventListener(
    'cancel',
    ((JSAny _) {
      if (!result.isCompleted) result.complete(null);
    }).toJS,
  );
  // Must run directly from the tap, or the browser blocks the file dialog.
  input.click();
  return result.future;
}
