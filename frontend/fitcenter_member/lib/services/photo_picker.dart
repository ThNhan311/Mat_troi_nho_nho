import 'dart:typed_data';

import 'photo_picker_stub.dart'
    if (dart.library.js_interop) 'photo_picker_web.dart'
    as platform;

class PickedPhoto {
  final Uint8List bytes;
  final String contentType;
  const PickedPhoto(this.bytes, this.contentType);
}

typedef PhotoPicker = Future<PickedPhoto?> Function();

/// True where a file can be chosen (the web build).
bool get canPickPhoto => platform.canPickPhoto;

/// Null when the user cancels.
Future<PickedPhoto?> pickPhoto() => platform.pickPhoto();
