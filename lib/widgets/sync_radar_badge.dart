import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/study_provider.dart';
import '../services/sync_service.dart';

class SyncRadarBadge extends StatelessWidget {
  const SyncRadarBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudyProvider>();
    final state = provider.syncState;

    Color badgeColor;
    IconData badgeIcon;

    switch (state) {
      case SyncState.synced:
        badgeColor = const Color(0xFF10B981);
        badgeIcon = Icons.cloud_done_rounded;
        break;
      case SyncState.syncing:
        badgeColor = const Color(0xFFF59E0B);
        badgeIcon = Icons.sync_rounded;
        break;
      case SyncState.offline:
        badgeColor = const Color(0xFFEF4444);
        badgeIcon = Icons.cloud_off_rounded;
        break;
    }

    return GestureDetector(
      onTap: () => _showSyncDetailsDialog(context, provider),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            state == SyncState.syncing
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                    ),
                  )
                : Icon(badgeIcon, size: 15, color: badgeColor),
            const SizedBox(width: 6),
            Text(
              state.label,
              style: TextStyle(
                color: badgeColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSyncDetailsDialog(BuildContext context, StudyProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF102A20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Text('🌐 Sync Radar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(provider.syncState.icon, style: const TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Status: ${provider.syncState.label}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              provider.syncState.description,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF08150F),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '• Your goals, forest, XP and notes are stored in Firebase Firestore\n'
                '• Signed in as ${provider.email ?? "unknown"}\n'
                '• Last synced: ${provider.lastSyncedAt == null ? "not yet" : provider.lastSyncedAt!.toLocal().toString().substring(0, 19)}'
                '${provider.cloudError != null ? "\n\n⚠️ ${provider.cloudError}" : ""}',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11.5, height: 1.5),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.syncNow();
              Navigator.of(ctx).pop();
            },
            child: const Text('Sync now', style: TextStyle(color: Color(0xFF10B981))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Color(0xFF38BDF8))),
          ),
        ],
      ),
    );
  }
}
