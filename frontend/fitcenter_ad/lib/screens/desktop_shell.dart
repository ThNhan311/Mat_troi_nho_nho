import 'package:flutter/material.dart';

/// Windows at least this wide get the desktop layout; narrower ones keep the
/// menu-and-back-button layout.
const adminDesktopBreakpoint = 1100.0;

class AdminSection {
  /// Sidebar heading this entry is listed under ('' for none).
  final String group;
  final IconData icon;
  final String title;
  final WidgetBuilder builder;

  /// Forms stay readable in a narrow column; lists and tables use more room.
  final double maxWidth;
  const AdminSection({
    required this.icon,
    required this.title,
    required this.builder,
    this.group = '',
    this.maxWidth = 880,
  });
}

/// Present only inside the desktop layout: pages drop their duplicate logout
/// buttons and can open another section.
class AdminDesktopScope extends InheritedWidget {
  final void Function(String title) open;
  const AdminDesktopScope({
    super.key,
    required this.open,
    required super.child,
  });

  static AdminDesktopScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminDesktopScope>();
  static bool isDesktop(BuildContext context) => of(context) != null;

  @override
  bool updateShouldNotify(AdminDesktopScope old) => false;
}

/// Permanent sidebar on the left, the selected section on the right.
class AdminDesktopShell extends StatefulWidget {
  final List<AdminSection> sections;
  final VoidCallback onLogout;
  final ValueChanged<bool> onToggleTheme;

  /// Shown under the menu, above the theme switch: acts instead of opening a page.
  final Widget? shortcut;
  const AdminDesktopShell({
    super.key,
    required this.sections,
    this.shortcut,
    required this.onLogout,
    required this.onToggleTheme,
  });
  @override
  State<AdminDesktopShell> createState() => _AdminDesktopShellState();
}

class _AdminDesktopShellState extends State<AdminDesktopShell> {
  int _selected = 0;

  void _select(int index) {
    if (index >= 0 && index != _selected) setState(() => _selected = index);
  }

  ThemeData _pageTheme(ThemeData theme) => theme.copyWith(
    appBarTheme: theme.appBarTheme.copyWith(
      centerTitle: false,
      toolbarHeight: 80,
      titleSpacing: 20,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      titleTextStyle: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: theme.colorScheme.onSurface,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final section = widget.sections[_selected];
    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 264, child: _sidebar(theme)),
          VerticalDivider(
            width: 1,
            color: theme.dividerColor.withValues(alpha: 0.18),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: section.maxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  // Each section has its own navigator, so its dialogs cover
                  // only the content and leaving it disposes its state.
                  child: ClipRect(
                    child: AdminDesktopScope(
                      open: (title) => _select(
                        widget.sections.indexWhere((s) => s.title == title),
                      ),
                      child: Theme(
                        data: _pageTheme(theme),
                        child: Navigator(
                          key: ValueKey('admin-section-$_selected'),
                          onGenerateRoute: (_) =>
                              MaterialPageRoute<void>(builder: section.builder),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebar(ThemeData theme) {
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final entries = <Widget>[];
    var group = '';
    for (var i = 0; i < widget.sections.length; i++) {
      final item = widget.sections[i];
      if (item.group != group) {
        group = item.group;
        entries.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 8, 8),
            child: Text(
              group.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      }
      entries.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: ListTile(
            key: ValueKey('admin-menu-$i'),
            dense: true,
            selected: i == _selected,
            selectedTileColor: colors.primary.withValues(alpha: 0.16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            leading: Icon(item.icon, size: 20),
            title: Text(item.title, style: const TextStyle(fontSize: 14)),
            onTap: () => _select(i),
          ),
        ),
      );
    }
    return Material(
      color: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.fitness_center, color: colors.primary, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'FITCENTER\nQuản trị',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: entries,
              ),
            ),
            if (widget.shortcut != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: widget.shortcut,
              ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: Icon(
                dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20,
              ),
              title: Text(dark ? 'Giao diện sáng' : 'Giao diện tối'),
              onTap: () => widget.onToggleTheme(!dark),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.logout, size: 20),
              title: const Text('Đăng xuất'),
              onTap: widget.onLogout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
