import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/pt_profile_service.dart';

/// Ready-made choices; anything else is typed in the box under them.
const specialtyChoices = [
  'Tăng cơ',
  'Giảm cân',
  'Tăng sức bền',
  'Cardio',
  'Yoga',
  'Pilates',
  'CrossFit',
  'Boxing',
  'Phục hồi chức năng',
];

const specializationLimit = 200;

/// The trainer edits what members see before booking them.
class TrainerProfilePage extends StatefulWidget {
  const TrainerProfilePage({super.key, required this.service});

  final PtProfileService service;

  @override
  State<TrainerProfilePage> createState() => _TrainerProfilePageState();
}

class _TrainerProfilePageState extends State<TrainerProfilePage> {
  final _experience = TextEditingController();
  final _bio = TextEditingController();
  final _other = TextEditingController();
  final _chosen = <String>{};

  bool _loaded = false, _busy = true, _unknown = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _experience.dispose();
    _bio.dispose();
    _other.dispose();
    super.dispose();
  }

  void _fill(TrainerProfile profile) {
    _experience.text = profile.experienceSummary;
    _bio.text = profile.bio;
    _chosen.clear();
    final rest = <String>[];
    for (final part in _parts(profile.specialization)) {
      final known = specialtyChoices
          .where((c) => c.toLowerCase() == part.toLowerCase())
          .firstOrNull;
      known == null ? rest.add(part) : _chosen.add(known);
    }
    _other.text = rest.join(', ');
  }

  static Iterable<String> _parts(String value) =>
      value.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);

  /// Chosen items first, in the order shown, then the typed ones.
  String get _specialization {
    final all = <String>[...specialtyChoices.where(_chosen.contains)];
    for (final part in _parts(_other.text)) {
      if (!all.any((a) => a.toLowerCase() == part.toLowerCase())) all.add(part);
    }
    return all.join(', ');
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await widget.service.read();
      if (!mounted) return;
      setState(() {
        _fill(profile);
        _loaded = true;
        _unknown = false;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được hồ sơ.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_loaded || _unknown) return;
    final specialization = _specialization;
    if (specialization.length > specializationLimit) {
      setState(
        () =>
            _error = 'Chuyên môn quá dài (tối đa $specializationLimit ký tự).',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.service.save(
        TrainerProfile(
          bio: _bio.text.trim(),
          specialization: specialization,
          experienceSummary: _experience.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() => _fill(saved));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Đã lưu hồ sơ.')));
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _unknown = e.outcomeUnknown || e.status == 0;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _unknown = true;
          _error = 'Chưa rõ kết quả.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ huấn luyện viên')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Hội viên sẽ thấy những thông tin này khi chọn PT.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                if (_loaded) ...[
                  _section(context, Icons.track_changes, 'Chuyên môn', [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final choice in specialtyChoices)
                          FilterChip(
                            label: Text(choice),
                            selected: _chosen.contains(choice),
                            onSelected: _busy
                                ? null
                                : (on) => setState(
                                    () => on
                                        ? _chosen.add(choice)
                                        : _chosen.remove(choice),
                                  ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      key: const Key('profile-other'),
                      controller: _other,
                      enabled: !_busy,
                      maxLength: specializationLimit,
                      decoration: const InputDecoration(
                        labelText: 'Chuyên môn khác',
                        helperText: 'Ngăn cách bằng dấu phẩy',
                      ),
                    ),
                  ]),
                  _section(context, Icons.work_outline, 'Kinh nghiệm', [
                    TextField(
                      key: const Key('profile-experience'),
                      controller: _experience,
                      enabled: !_busy,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: 'Ví dụ: 3 năm huấn luyện cá nhân',
                      ),
                    ),
                  ]),
                  _section(context, Icons.person_outline, 'Giới thiệu', [
                    TextField(
                      key: const Key('profile-bio'),
                      controller: _bio,
                      enabled: !_busy,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText: 'Phong cách huấn luyện, chứng chỉ...',
                      ),
                    ),
                  ]),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      key: const Key('profile-error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                if (_unknown)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Chưa rõ đã lưu chưa. Hãy tải lại hồ sơ để kiểm tra; '
                      'nội dung đang nhập sẽ được thay bằng bản trên máy chủ.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_busy) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                ],
                // Without the current profile, saving could erase it.
                if (!_busy && (!_loaded || _unknown))
                  OutlinedButton.icon(
                    key: const Key('profile-reload'),
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tải lại hồ sơ'),
                  )
                else if (_loaded)
                  FilledButton(
                    key: const Key('profile-save'),
                    onPressed: _busy || _unknown ? null : _save,
                    child: const Text('Lưu hồ sơ'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context,
    IconData icon,
    String title,
    List<Widget> children,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
