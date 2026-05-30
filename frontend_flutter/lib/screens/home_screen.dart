import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_session.dart';
import 'login_screen.dart';
import 'manager/manager_dashboard_screen.dart';
import 'worker/worker_history_screen.dart';
import 'worker/worker_inspection_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppUser user;

  const HomeScreen({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await AuthSession.clear();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Container Inspection',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose the workflow you want to open.',
                style: TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${user.fullName} - ${user.role.toUpperCase()}',
                style: const TextStyle(
                  color: Color(0xFF075DCC),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 32),
              if (user.canSubmitInspection) ...[
                _RoleCard(
                  icon: Icons.photo_camera_rounded,
                  title: 'Worker Inspection',
                  subtitle: 'Capture container photos and submit to office.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WorkerInspectionScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.history_rounded,
                  title: 'Worker History',
                  subtitle: 'View your submitted, accepted, and rejected jobs.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WorkerHistoryScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (user.canReviewInspections)
                _RoleCard(
                  icon: Icons.verified_user_rounded,
                  title: 'Manager Review',
                  subtitle: 'Review submitted photos, accept, reject, export.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ManagerDashboardScreen(),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF075DCC).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF075DCC),
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
