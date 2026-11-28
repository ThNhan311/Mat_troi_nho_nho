import 'renewal_page.dart';
import '../services/renewal_service.dart';

import 'package:flutter/material.dart';

import '../services/booking_models.dart';
import '../services/membership_service.dart';
import '../widgets/detail_row.dart';
import '../widgets/page_header.dart';
import '../widgets/pull_to_reload.dart';

class MembershipPage extends StatefulWidget {
  final MembershipService service;
  final bool active;

  /// The signed-in member, shown on the package card when known.
  final String? memberName, memberId;
  const MembershipPage({
    super.key,
    required this.service,
    this.active = true,
    this.memberName,
    this.memberId,
  });
  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  List<Membership> memberships = [];
  bool loading = false;
  String? error;
  int request = 0;
  @override
  void initState() {
    super.initState();
    widget.service.api.addListener(sessionChanged);
    if (widget.active) load();
  }

  void sessionChanged() {
    request++;
    if (mounted) {
      setState(() {
        memberships = [];
        error = null;
        loading = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant MembershipPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) load();
  }

  Future<void> load() async {
    final ticket = ++request;
    final epoch = widget.service.api.sessionEpoch;
    setState(() {
      loading = true;
      error = null;
      memberships = [];
    });
    try {
      final rows = await widget.service.mine();
      if (!mounted ||
          ticket != request ||
          epoch != widget.service.api.sessionEpoch) {
        return;
      }
      setState(() => memberships = rows);
    } catch (failure) {
      if (!mounted ||
          ticket != request ||
          epoch != widget.service.api.sessionEpoch) {
        return;
      }
      setState(() => error = failure.toString());
    } finally {
      if (mounted &&
          ticket == request &&
          epoch == widget.service.api.sessionEpoch) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    request++;
    widget.service.api.removeListener(sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: PullToReload(
        onReload: () async {
          if (!loading) await load();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                icon: Icons.card_membership,
                title: 'Gói hội viên',
                subtitle: 'Quản lý gói tập của bạn',
              ),
              const SizedBox(height: 24),
              if (loading)
                const LinearProgressIndicator(key: Key('membership-loading')),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    error!,
                    key: const Key('membership-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (!loading && error == null && memberships.isEmpty)
                const Text(
                  'Bạn chưa có gói hội viên.',
                  key: Key('membership-empty'),
                ),
              for (final row in memberships)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: card(context, row),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget card(BuildContext context, Membership row) => Container(
    key: ValueKey('membership-${row.id}'),
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.card_membership,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Only an active package is the current one.
                  if (row.status == 'ACTIVE') ...[
                    Text(
                      'Gói hiện tại',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    row.planName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          row.statusLabel,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.memberName case final name?) DetailRow('Tên hội viên', name),
        if (widget.memberId case final id? when id.length >= 8)
          DetailRow('Mã hội viên', shortId(id).toUpperCase()),
        DetailRow('Ngày bắt đầu', Membership.displayDate(row.startDate)),
        DetailRow('Ngày kết thúc', Membership.displayDate(row.endDate)),
        // Same one-line layout as the dates; the code can still be copied.
        SelectionArea(
          child: DetailRow('Mã gói', shortId(row.id).toUpperCase()),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => Navigator.of(context)
                .push(
                  MaterialPageRoute<void>(
                    builder: (_) => RenewalPage(
                      service: RenewalService(widget.service.api),
                      membershipId: row.id,
                    ),
                  ),
                )
                .then((_) {
                  if (mounted && widget.service.api.authenticated) load();
                }),
            child: const Text('Gia hạn Membership'),
          ),
        ),
      ],
    ),
  );
}
