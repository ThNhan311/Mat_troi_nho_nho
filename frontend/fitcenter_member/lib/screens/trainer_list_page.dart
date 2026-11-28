import 'package:flutter/material.dart';

import '../services/booking_models.dart';
import '../services/booking_state.dart';
import '../services/vietnam_time.dart';
import '../widgets/api_status.dart';
import '../widgets/page_header.dart';
import '../widgets/pull_to_reload.dart';
import '../widgets/trainer_photo.dart';
import '../widgets/trainer_showcase_card.dart';
import 'trainer_detail_page.dart';

class TrainerListPage extends StatefulWidget {
  final BookingState state;
  final ValueChanged<String> onShowMessage;
  final ValueChanged<String> onSelectTrainerForBooking;

  /// Whether this tab is on screen; free sessions are only read then.
  final bool active;

  const TrainerListPage({
    super.key,
    required this.onShowMessage,
    required this.state,
    required this.onSelectTrainerForBooking,
    this.active = true,
  });

  @override
  State<TrainerListPage> createState() => _TrainerListPageState();
}

class _TrainerListPageState extends State<TrainerListPage> {
  /// Only trainers whose free sessions the server answered for.
  Map<String, OpenSlots> _open = {};
  String? _specialty;
  bool _wasLoading = false, _started = false;
  int _ticket = 0;

  BookingState get state => widget.state;

  @override
  void initState() {
    super.initState();
    state.addListener(_onState);
    _sync(false);
  }

  @override
  void didUpdateWidget(TrainerListPage old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      old.state.removeListener(_onState);
      widget.state.addListener(_onState);
    }
    if (widget.active && !old.active) _sync(true);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onState);
    super.dispose();
  }

  void _onState() => _sync(false);

  /// Reads after the trainers arrive, and again after every reload.
  void _sync(bool returned) {
    final ready = state.loaded && !state.loading && state.alive;
    if (!widget.active) {
      // A reload made elsewhere is picked up when the tab comes back.
      if (state.loading) _started = false;
      _wasLoading = state.loading;
      return;
    }
    if (ready && (!_started || _wasLoading || returned)) {
      _started = true;
      _loadOpenSlots();
    }
    _wasLoading = state.loading;
  }

  Future<void> _loadOpenSlots() async {
    final ticket = ++_ticket;
    final api = state.service.api;
    final epoch = api.sessionEpoch;
    final now = DateTime.now().toUtc();
    final answers = <String, OpenSlots>{};
    await Future.wait([
      for (final trainer in state.trainers)
        () async {
          try {
            // Decoration only: it never renews or ends the session.
            final rows = items(
              await api.peek(
                '/trainers/${trainer.id}/slots',
                query: queryRange(now, state.to),
              ),
              Slot.fromJson,
            );
            final free =
                rows
                    .where(
                      (s) => s.status == 'AVAILABLE' && s.startAt.isAfter(now),
                    )
                    .toList()
                  ..sort((a, b) => a.startAt.compareTo(b.startAt));
            answers[trainer.id] = OpenSlots(free);
          } catch (_) {
            // Not the same as "no free time", so the card says nothing.
          }
        }(),
    ]);
    if (mounted && ticket == _ticket && epoch == api.sessionEpoch) {
      setState(() => _open = answers);
    }
  }

  void _openProfile(Trainer trainer) => state.act(() async {
    final detail = await state.service.trainer(trainer.id);
    if (!mounted || !state.alive) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TrainerDetailPage(
          trainerName: detail.fullName,
          photo: TrainerPhoto(
            api: state.service.api,
            id: detail.id,
            name: detail.fullName,
            size: TrainerDetailPage.photoSize,
          ),
          bio: detail.bio,
          specialization: detail.specialization,
          experience: detail.experienceSummary,
          phone: detail.phone,
          gender: detail.gender,
          slots: _open[trainer.id]?.upcoming,
          onShowMessage: widget.onShowMessage,
          onBookAppointment: () {
            Navigator.pop(context);
            widget.onSelectTrainerForBooking(detail.id);
          },
        ),
      ),
    );
  });

  /// Every specialty once, however it was capitalised.
  List<String> get _specialties {
    final seen = <String, String>{};
    for (final trainer in state.trainers) {
      for (final item in specialtiesOf(trainer)) {
        seen.putIfAbsent(item.toLowerCase(), () => item);
      }
    }
    return seen.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final specialties = _specialties;
    // A filter that no longer exists falls back to everyone.
    final chosen = state.trainers.length > 1 && specialties.contains(_specialty)
        ? _specialty
        : null;
    final trainers = [
      for (final trainer in state.trainers)
        if (chosen == null ||
            specialtiesOf(trainer)
                .any((s) => s.toLowerCase() == chosen.toLowerCase()))
          trainer,
    ];

    return Scaffold(
      body: SafeArea(
        child: PullToReload(
          onReload: () => PullToReload.bookings(state),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeader(
                  // A coach's whistle.
                  icon: Icons.sports,
                  title: 'Huấn luyện viên',
                  subtitle: 'Tìm PT phù hợp với mục tiêu của bạn',
                ),
                ApiStatus(state: state),
                // One trainer leaves nothing to filter.
                if (state.trainers.length > 1 && specialties.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final item in [null, ...specialties])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(item ?? 'Tất cả'),
                              selected: chosen == item,
                              onSelected: (_) =>
                                  setState(() => _specialty = item),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Danh sách PT',
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${trainers.length} huấn luyện viên',
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (!state.loading && trainers.isEmpty)
                  const Text('Chưa có huấn luyện viên để hiển thị.'),
                for (final trainer in trainers)
                  TrainerShowcaseCard(
                    key: ValueKey('trainer-card-${trainer.id}'),
                    trainer: trainer,
                    api: state.service.api,
                    open: _open[trainer.id],
                    onOpenProfile: state.blocked
                        ? null
                        : () => _openProfile(trainer),
                    onBook: state.blocked
                        ? null
                        : () => widget.onSelectTrainerForBooking(trainer.id),
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
