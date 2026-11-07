import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/study_provider.dart';
import '../services/auth_service.dart';

/// Avatar button with account actions (sync, AI backend info, demo data, sign out).
class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<StudyProvider>();
    final initial = p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : '?';

    return PopupMenuButton<String>(
      tooltip: 'Account',
      color: const Color(0xFF0B1F17),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white12)),
      onSelected: (v) => _onSelected(context, p, v),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0xFF10B981),
        child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text(p.email ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ),
        const PopupMenuDivider(),
        _item('sync', Icons.cloud_sync_rounded, 'Sync now'),
        _item('groq', Icons.smart_toy_rounded, 'AI connection test'),
        _item('demo', Icons.auto_graph_rounded, 'Load sample data'),
        const PopupMenuDivider(),
        _item('out', Icons.logout_rounded, 'Sign out', color: const Color(0xFFEF4444)),
      ],
    );
  }

  PopupMenuItem<String> _item(String v, IconData icon, String label, {Color color = Colors.white}) {
    return PopupMenuItem<String>(
      value: v,
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ]),
    );
  }

  Future<void> _onSelected(BuildContext context, StudyProvider p, String v) async {
    switch (v) {
      case 'sync':
        await p.syncNow();
        break;
      case 'groq':
  _groqDialog(context,p);
  break;
      case 'demo':
        p.loadDemoData();
        break;
      case 'out':
        await AuthService.instance.signOut();
        break;
    }
  }

  void _groqDialog(BuildContext context, StudyProvider p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1F17),
        title: const Text('AI connection test', style: TextStyle(color: Colors.white)),
        content: FutureBuilder<String?>(
          future: p.testAi(),
          builder: (c, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Contacting the AI...', style: TextStyle(color: Colors.white70)),
              ]);
            }
            final problem = snap.data;
            return Text(
              problem == null
                  ? '✅ The AI is connected and working.'
                  : '⚠️ $problem',
              style: TextStyle(color: problem == null ? const Color(0xFF34D399) : const Color(0xFFFBBF24), fontSize: 14),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
