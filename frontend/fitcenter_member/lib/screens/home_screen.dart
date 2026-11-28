import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../widgets/brand_logo.dart';

import '../widgets/avatar.dart';
import '../widgets/feature_tile.dart';
import '../widgets/overview_section.dart';
import '../widgets/api_status.dart';
import '../services/booking_state.dart';
import '../widgets/pull_to_reload.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.state,
    required this.bookingConfirmed,
    this.active = true,
    required this.onOpenSchedule,
    required this.onOpenMembership,
    required this.onOpenProfile,
    required this.onShowMessage,
    this.photo,
    this.name,
  });

  final bool bookingConfirmed;
  final bool active;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenMembership;
  final VoidCallback onOpenProfile;
  final void Function(String message) onShowMessage;
  final Uint8List? photo;
  final String? name;

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: PullToReload(
        onReload: () => PullToReload.bookings(state),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),

          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreeting(context),
              ApiStatus(state: state),
              const SizedBox(height: 22),
              _buildHeroCard(context),
              const SizedBox(height: 28),
              _sectionTitle('Tổng quan'),
              const SizedBox(height: 14),
              OverviewSection(
                state: state,
                active: active,
                onOpenSchedule: onOpenSchedule,
                onOpenMembership: onOpenMembership,
              ),
              const SizedBox(height: 28),
              _sectionTitle('Khám phá FitCenter'),
              const SizedBox(height: 14),
              FeatureTile(
                icon: Icons.card_membership,
                title: 'Gói tập của tôi',
                subtitle: 'Theo dõi thông tin hội viên',
                onTap: onOpenMembership,
              ),
              const SizedBox(height: 10),
              FeatureTile(
                icon: Icons.calendar_month,
                title: 'Lịch tập',
                subtitle: 'Quản lý lịch tập của bạn',
                onTap: onOpenSchedule,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
  );

  Widget _buildGreeting(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: onOpenProfile,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
            child: AvatarCircle(image: photo, size: 46),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: name == null
              ? const Text(
                  'Xin chào hội viên!',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xin chào hội viên,',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$name!',
                      key: const Key('greeting-name'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(width: 12),
        const BrandLogo(key: Key('home-logo'), width: 120),
      ],
    );
  }

  /// The campaign banner keeps its own ratio so no artwork is cropped.
  Widget _buildHeroCard(BuildContext context) {
    // Matches the dark edge of the artwork, in both light and dark mode.
    const base = Color(0xFF121411);
    const lime = Color(0xFFCBF31D);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1672 / 941,
                child: Image.asset(
                  'assets/images/home_banner.webp',
                  key: const Key('home-banner'),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  semanticLabel: 'FitCenter: Push your limits',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'YOUR FITNESS JOURNEY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: onOpenSchedule,
                      style: FilledButton.styleFrom(
                        backgroundColor: lime,
                        foregroundColor: base,
                      ),
                      icon: const Icon(Icons.calendar_month, size: 20),
                      label: const Text('Đặt lịch tập'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
