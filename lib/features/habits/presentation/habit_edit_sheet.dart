// lib/features/habits/presentation/habit_edit_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:furrow/core/providers/core_providers.dart';
import 'package:furrow/features/habits/domain/habit_enums.dart';
import 'package:furrow/shared/theme/app_spacing.dart';

const _habitSwatches = <int>[
  0xFFB07A2E, // furrow ochre
  0xFF5E9478, // sage
  0xFF5C7599, // slate
  0xFFA85040, // terracotta
  0xFFC49A3C, // amber
  0xFF7A6C9C, // muted violet
  0xFF4E7D65, // pine
  0xFF8C6A58, // walnut
];

/// Create or edit a habit. Cadence (and its target) is the main choice; on edit
/// the cadence is fixed (changing it against existing marks is nonsensical).
class HabitEditSheet extends ConsumerStatefulWidget {
  const HabitEditSheet({super.key, this.habitId});
  final String? habitId; // null = create

  @override
  ConsumerState<HabitEditSheet> createState() => _HabitEditSheetState();
}

class _HabitEditSheetState extends ConsumerState<HabitEditSheet> {
  final _name = TextEditingController();
  final _unit = TextEditingController();
  Cadence _cadence = Cadence.binary;
  int _countTarget = 8;
  int _durationMins = 20;
  ScheduleType _schedule = ScheduleType.daily;
  int _weekdayMask = kDailyMask;
  int _color = _habitSwatches.first;
  bool _loading = true;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    if (widget.habitId == null) {
      _loading = false;
    } else {
      _editing = true;
      _load();
    }
  }

  Future<void> _load() async {
    final h = await ref.read(habitsRepositoryProvider).getHabit(widget.habitId!);
    if (h == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _name.text = h.name;
      _cadence = Cadence.fromName(h.cadence);
      _schedule = ScheduleType.fromName(h.scheduleType);
      _weekdayMask = h.weekdayMask;
      _color = h.colorValue;
      _unit.text = h.unit ?? '';
      if (_cadence == Cadence.count) _countTarget = h.targetValue;
      if (_cadence == Cadence.duration) _durationMins = (h.targetValue / 60).round();
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    super.dispose();
  }

  int get _targetValue => switch (_cadence) {
        Cadence.binary => 1,
        Cadence.count => _countTarget,
        Cadence.duration => _durationMins * 60,
      };

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(habitsRepositoryProvider);
    if (_editing) {
      final h = await repo.getHabit(widget.habitId!);
      if (h == null) return;
      await repo.updateHabit(
        h,
        name: name,
        targetValue: _targetValue,
        unit: _cadence == Cadence.count ? _unit.text.trim() : null,
        scheduleType: _schedule,
        weekdayMask: _weekdayMask,
        colorValue: _color,
      );
    } else {
      await repo.createHabit(
        name: name,
        cadence: _cadence,
        targetValue: _targetValue,
        unit: _cadence == Cadence.count && _unit.text.trim().isNotEmpty
            ? _unit.text.trim()
            : null,
        scheduleType: _schedule,
        weekdayMask: _weekdayMask,
        colorValue: _color,
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit habit' : 'Plant a habit'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(_editing ? 'Save' : 'Plant'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            autofocus: !_editing,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Read, Walk, Tidy the kitchen',
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel('How is it done?'),
          const SizedBox(height: AppSpacing.sm),
          if (_editing)
            _CadenceCard(cadence: _cadence, selected: true, onTap: () {})
          else
            for (final c in Cadence.values) ...[
              _CadenceCard(
                cadence: c,
                selected: _cadence == c,
                onTap: () => setState(() => _cadence = c),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          if (_cadence == Cadence.count) ...[
            const SizedBox(height: AppSpacing.sm),
            _Stepper(
              label: 'Daily target',
              value: _countTarget,
              suffix: _unit.text.trim().isEmpty ? 'times' : _unit.text.trim(),
              onChanged: (v) => setState(() => _countTarget = v.clamp(1, 99)),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _unit,
              decoration: const InputDecoration(
                labelText: 'Unit (optional)',
                hintText: 'glasses, pages, reps…',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          if (_cadence == Cadence.duration) ...[
            const SizedBox(height: AppSpacing.sm),
            _Stepper(
              label: 'Daily target',
              value: _durationMins,
              suffix: 'min',
              step: 5,
              onChanged: (v) => setState(() => _durationMins = v.clamp(1, 600)),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel('When?'),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<ScheduleType>(
            segments: const [
              ButtonSegment(value: ScheduleType.daily, label: Text('Every day')),
              ButtonSegment(
                  value: ScheduleType.specificDays, label: Text('Some days')),
            ],
            selected: {_schedule},
            onSelectionChanged: (s) => setState(() => _schedule = s.first),
          ),
          if (_schedule == ScheduleType.specificDays) ...[
            const SizedBox(height: AppSpacing.sm),
            _WeekdayPicker(
              mask: _weekdayMask,
              onChanged: (m) => setState(() => _weekdayMask = m),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel('Colour'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final c in _habitSwatches)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: _color == c
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 3)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
}

class _CadenceCard extends StatelessWidget {
  const _CadenceCard(
      {required this.cadence, required this.selected, required this.onTap});
  final Cadence cadence;
  final bool selected;
  final VoidCallback onTap;

  (IconData, String, String) get _meta => switch (cadence) {
        Cadence.binary => (LucideIcons.check, 'A daily tick', 'Done or not, each day'),
        Cadence.count => (LucideIcons.plus, 'A number', 'Reach a count each day'),
        Cadence.duration => (LucideIcons.timer, 'Some time', 'Log time with a timer'),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, title, sub) = _meta;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected ? cs.primary.withValues(alpha: 0.06) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(sub,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            if (selected) Icon(LucideIcons.check, color: cs.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
    this.suffix = '',
    this.step = 1,
  });
  final String label;
  final int value;
  final String suffix;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.titleMedium)),
        IconButton.outlined(
          onPressed: () => onChanged(value - step),
          icon: const Icon(LucideIcons.minus, size: 18),
        ),
        SizedBox(
          width: 84,
          child: Text(
            '$value $suffix',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton.outlined(
          onPressed: () => onChanged(value + step),
          icon: const Icon(LucideIcons.plus, size: 18),
        ),
      ],
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.mask, required this.onChanged});
  final int mask;
  final ValueChanged<int> onChanged;
  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < 7; i++)
          FilterChip(
            label: Text(_letters[i]),
            selected: (mask & (1 << i)) != 0,
            onSelected: (sel) {
              final bit = 1 << i;
              onChanged(sel ? (mask | bit) : (mask & ~bit));
            },
          ),
      ],
    );
  }
}
