import 'package:flutter/material.dart';

class ShellDestination {
  const ShellDestination({
    required this.path,
    required this.label,
    required this.icon,
  });

  final String path;
  final String label;
  final IconData icon;

  static const inbox = ShellDestination(
    path: '/inbox',
    label: 'Inbox',
    icon: Icons.inbox_outlined,
  );
  static const today = ShellDestination(
    path: '/today',
    label: 'Today',
    icon: Icons.today_outlined,
  );
  static const upcoming = ShellDestination(
    path: '/upcoming',
    label: 'Upcoming',
    icon: Icons.calendar_month_outlined,
  );
  static const settings = ShellDestination(
    path: '/settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
  );

  static const values = [inbox, today, upcoming, settings];

  static ShellDestination? fromLocation(String location) {
    for (final destination in values) {
      if (location == destination.path) return destination;
    }
    return null;
  }
}
