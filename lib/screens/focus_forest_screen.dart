import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/study_provider.dart';
import '../models/forest_tree.dart';
import '../widgets/forest_painters.dart';

class FocusForestScreen extends StatelessWidget {
  const FocusForestScreen({super.key});

  static const _durations = [15, 25, 45, 60];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudyProvider>();
    final progress = provider.timerProgress;
    final mm = (provider.timerSecondsRemaining ~/ 60).toString().padLeft(2, '0');
    final ss = (provider.timerSecondsRemaining % 60).toString().padLeft(2, '0');
    final species = provider.selectedTreeSpecies;
    final minutes = provider.timerTotalSeconds ~/ 60;

    return Scaffold(
      body: ForestBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    _header(provider),
                    const SizedBox(height: 14),
                    _sessionCard(context, provider),
                    const SizedBox(height: 10),

                    // Tree stage
                    GrowingTree(species: species, progress: progress, height: 310),
                    Text(
                      '$mm:$ss',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 58,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        shadows: [Shadow(color: Color(0xFF10B981), blurRadius: 24)],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _stageLabel(progress, provider.isTimerRunning),
                      style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    if (provider.isTimerRunning) ...[
                      const SizedBox(height: 10),
                      _stayBanner(),
                    ],
                    if (provider.justPlanted) ...[
                      const SizedBox(height: 12),
                      _plantedBanner(),
                    ],
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Duration chips
                    Wrap(
                      spacing: 8,
                      children: _durations.map((d) {
                        final sel = d == minutes;
                        return ChoiceChip(
                          label: Text('$d min'),
                          selected: sel,
                          selectedColor: const Color(0xFF10B981).withValues(alpha: 0.35),
                          backgroundColor: const Color(0xFF06231B).withValues(alpha: 0.8),
                          labelStyle: TextStyle(color: sel ? const Color(0xFF6EE7B7) : Colors.white70, fontWeight: FontWeight.bold),
                          side: BorderSide(color: sel ? const Color(0xFF34D399) : Colors.white12),
                          onSelected: provider.isTimerRunning ? null : (_) => provider.setTimerMinutes(d),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Species picker
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: TreeSpecies.values.map((sp) {
                          final sel = species == sp;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Row(children: [
                                Text(sp.emoji, style: const TextStyle(fontSize: 15)),
                                const SizedBox(width: 6),
                                Text(sp.displayName),
                              ]),
                              selected: sel,
                              selectedColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                              backgroundColor: const Color(0xFF06231B).withValues(alpha: 0.8),
                              labelStyle: TextStyle(
                                color: sel ? const Color(0xFF6EE7B7) : Colors.white70,
                                fontSize: 12,
                                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                              ),
                              side: BorderSide(color: sel ? const Color(0xFF34D399) : Colors.white12),
                              onSelected: provider.isTimerRunning ? null : (_) => provider.selectTreeSpecies(sp),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Best for: ${species.description}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 20),

                    _controls(context, provider),
                    const SizedBox(height: 28),

                    _gardenSection(provider),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glass({required Widget child, EdgeInsets padding = const EdgeInsets.all(14)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF06231B).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.25)),
      ),
      child: child,
    );
  }

  Widget _header(StudyProvider provider) {
    final thriving = provider.forestTrees.where((t) => !t.isWithered).length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🌲 Focus Forest', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
            Text('Stay focused. Watch your woodland grow.', style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 12.5)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF06231B).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
          ),
          child: Text('🌳 $thriving', style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _sessionCard(BuildContext context, StudyProvider provider) {
    final goal = provider.activeGoal;
    return _glass(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF38BDF8).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.school_rounded, color: Color(0xFF38BDF8), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Studying now', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                Text(goal?.title ?? 'General focus session',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(goal?.subject ?? 'Any subject', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ],
            ),
          ),
          PopupMenuButton<int>(
            tooltip: 'Choose goal',
            color: const Color(0xFF0B1F17),
            icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF34D399)),
            enabled: !provider.isTimerRunning,
            onSelected: (i) {
              final mins = provider.timerTotalSeconds ~/ 60;
              if (i < 0) {
                provider.setTimerGoal(null, minutes: mins);
              } else {
                provider.setTimerGoal(provider.goals[i], minutes: mins);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: -1, child: Text('General focus session', style: TextStyle(color: Colors.white))),
              for (var i = 0; i < provider.goals.length; i++)
                PopupMenuItem(
                  value: i,
                  child: SizedBox(
                    width: 280,
                    child: Text(provider.goals[i].title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stayBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66F59E0B)),
      ),
      child: const Text(
        '📵 Stay focused: the screen is in full screen. Leaving it or opening other tabs/apps withers your tree. Tabs inside this app still work.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFFFCD34D), fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _plantedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF34D399)),
      ),
      child: const Text('🎉 Your tree is planted in the forest!  +10 XP',
          style: TextStyle(color: Color(0xFF6EE7B7), fontWeight: FontWeight.w800)),
    );
  }

  Widget _controls(BuildContext context, StudyProvider provider) {
    if (!provider.isTimerRunning) {
      final started = provider.timerSecondsRemaining != provider.timerTotalSeconds;
      return ElevatedButton.icon(
        onPressed: provider.startFocusTimer,
        icon: const Icon(Icons.eco_rounded, size: 26),
        label: Text(started ? 'Resume growing' : 'Plant & Start Focus',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: const Color(0xFF10B981),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: provider.pauseFocusTimer,
          icon: const Icon(Icons.pause_rounded, size: 24),
          label: const Text('Pause'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(width: 14),
        OutlinedButton.icon(
          onPressed: () => _confirmAbandon(context, provider),
          icon: const Icon(Icons.close_rounded, size: 22),
          label: const Text('Give Up'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEF4444),
            side: const BorderSide(color: Color(0xFFEF4444)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  String _stageLabel(double p, bool running) {
    if (p == 0.0) return running ? 'Planting the seed...' : 'Ready to plant a seed';
    if (p < 0.10) return 'Stage 1: Seed is sprouting 🌱';
    if (p < 0.40) return 'Stage 2: Growing taller 🌿';
    if (p < 0.75) return 'Stage 3: Branches spreading 🪴';
    if (p < 1.0) return 'Stage 4: Almost in full bloom 🌳';
    return 'Fully grown!';
  }

  void _confirmAbandon(BuildContext context, StudyProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1F17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Text('🥀 Give Up Session?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leaving now will cause your tree to wither and die in your forest!',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            if (provider.userProfile.streakShields > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Text('🛡️', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You have ${provider.userProfile.streakShields} Streak Shields. You can use 1 shield to protect the tree and forgive this session.',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Studying', style: TextStyle(color: Color(0xFF10B981))),
          ),
          if (provider.userProfile.streakShields > 0)
            ElevatedButton(
              onPressed: () {
                provider.abandonFocusTimer(useShield: true);
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
              child: const Text('Use Shield 🛡️', style: TextStyle(color: Colors.black)),
            ),
          TextButton(
            onPressed: () {
              provider.abandonFocusTimer(useShield: false);
              Navigator.of(ctx).pop();
            },
            child: const Text('Wither Tree 🥀', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  Widget _gardenSection(StudyProvider provider) {
    final trees = provider.forestTrees;
    final thriving = trees.where((t) => !t.isWithered).length;
    final withered = trees.length - thriving;
    return _glass(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏡 My Forest', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ForestGardenScene(trees: trees, height: 260),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat('🌳', '$thriving', 'Thriving'),
              _stat('🥀', '$withered', 'Withered'),
              _stat('⏱️', '${provider.totalFocusMinutes}', 'Focus min'),
              _stat('🛡️', '${provider.userProfile.streakShields}', 'Shields'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String emoji, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }
}
