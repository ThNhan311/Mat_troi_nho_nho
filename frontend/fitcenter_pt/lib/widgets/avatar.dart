import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/photo_picker.dart';

const maxAvatarBytes = 5 * 1024 * 1024;

class AvatarCircle extends StatelessWidget {
  final Uint8List? image;
  final double size;
  const AvatarCircle({super.key, required this.image, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final fallback = Icon(Icons.person, size: size * 0.55, color: color);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        shape: BoxShape.circle,
      ),
      child: image == null
          ? fallback
          : Image.memory(
              image!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

/// Another person's picture (read only). Any failure shows the default icon.
class RemoteAvatar extends StatefulWidget {
  final ApiClient api;
  final String path;
  final double size;
  final Widget? fallback;
  const RemoteAvatar({
    super.key,
    required this.api,
    required this.path,
    required this.size,
    this.fallback,
  });
  @override
  State<RemoteAvatar> createState() => _RemoteAvatarState();
}

class _RemoteAvatarState extends State<RemoteAvatar> {
  Uint8List? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RemoteAvatar old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _image = null;
      _load();
    }
  }

  Future<void> _load() async {
    final path = widget.path;
    try {
      final image = await widget.api.picture('GET', path: path);
      if (mounted && path == widget.path) setState(() => _image = image);
    } catch (_) {
      // A missing picture must never break the list.
    }
  }

  @override
  Widget build(BuildContext context) =>
      _image == null && widget.fallback != null
      ? widget.fallback!
      : AvatarCircle(image: _image, size: widget.size);
}

/// The signed-in user's own picture: tap to choose, with a remove action.
class AvatarEditor extends StatefulWidget {
  final ApiClient api;
  final double size;
  final ValueChanged<String> onMessage;
  final PhotoPicker? picker;

  /// The picture is requested only once the editor is actually on screen.
  final bool active;
  const AvatarEditor({
    super.key,
    required this.api,
    required this.size,
    required this.onMessage,
    this.picker,
    this.active = true,
  });
  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> {
  Uint8List? _image;
  bool _busy = false;
  bool _requested = false;

  bool get _canPick => widget.picker != null || canPickPhoto;

  @override
  void initState() {
    super.initState();
    _loadWhenShown();
  }

  @override
  void didUpdateWidget(AvatarEditor old) {
    super.didUpdateWidget(old);
    _loadWhenShown();
  }

  void _loadWhenShown() {
    if (!widget.active || _requested) return;
    _requested = true;
    _load();
  }

  Future<void> _load() async {
    try {
      final image = await widget.api.picture('GET');
      if (mounted) setState(() => _image = image);
    } catch (_) {
      // Keep the default icon.
    }
  }

  Future<void> _choose() async {
    if (_busy) return;
    final PickedPhoto? photo;
    try {
      photo = await (widget.picker ?? pickPhoto)();
    } catch (_) {
      if (mounted) widget.onMessage('Không đọc được ảnh đã chọn.');
      return;
    }
    if (photo == null || !mounted) return;
    if (photo.contentType != 'image/jpeg' && photo.contentType != 'image/png') {
      widget.onMessage('Chỉ nhận ảnh JPG hoặc PNG.');
      return;
    }
    if (photo.bytes.length > maxAvatarBytes) {
      widget.onMessage('Ảnh tối đa 5 MB.');
      return;
    }
    await _change(
      () => widget.api.picture(
        'PUT',
        bytes: photo!.bytes,
        contentType: photo.contentType,
      ),
      'Đã đổi ảnh đại diện.',
    );
  }

  Future<void> _change(Future<Object?> Function() send, String done) async {
    setState(() => _busy = true);
    try {
      await send();
      await _load();
      if (mounted) widget.onMessage(done);
    } on ApiError catch (error) {
      if (mounted) {
        widget.onMessage(
          error.status == 404
              ? 'Máy chủ chưa bật ảnh đại diện.'
              : error.status == 400
              ? 'Ảnh không hợp lệ. Hãy chọn ảnh JPG hoặc PNG khác.'
              : error.message,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() => _change(() async {
    await widget.api.picture('DELETE');
    if (mounted) setState(() => _image = null);
    return null;
  }, 'Đã xóa ảnh đại diện.');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: _canPick ? 'Chọn ảnh đại diện' : 'Ảnh đại diện',
          child: InkWell(
            key: const Key('avatar'),
            customBorder: const CircleBorder(),
            onTap: _canPick && !_busy ? _choose : null,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AvatarCircle(image: _image, size: widget.size),
                if (_busy) const CircularProgressIndicator(),
                if (_canPick)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: colors.primary,
                      child: Icon(
                        Icons.photo_camera,
                        size: 16,
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_image != null)
          TextButton(
            onPressed: _busy ? null : _remove,
            child: const Text('Xóa ảnh'),
          ),
      ],
    );
  }
}
