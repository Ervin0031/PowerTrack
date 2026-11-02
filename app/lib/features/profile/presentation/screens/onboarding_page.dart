import 'package:app_flutter/core/network/network.dart';
import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/features/auth/application/providers/auth_controller.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/features/profile/domain/entities/fitness_profile.dart';
import 'package:app_flutter/features/profile/presentation/widgets/onboarding_choice_card.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

const _totalSteps = 7;
const _minBirthYear = 1926;
const _maxBirthYear = 2018;
const _minHeight = 100;
const _maxHeight = 250;
const _minWeight = 30.0;
const _maxWeight = 300.0;

/// 新用户健身档案引导：7 步，每步写入本地，最后一次性提交。
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pageController = PageController();
  int _step = 0;
  bool _generating = false;
  late final FixedExtentScrollController _yearCtrl;
  late final FixedExtentScrollController _heightCtrl;
  late final FixedExtentScrollController _weightCtrl;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingProvider);
    _yearCtrl = FixedExtentScrollController(
      initialItem: (draft.birthYear - _minBirthYear).clamp(0, _maxBirthYear - _minBirthYear),
    );
    _heightCtrl = FixedExtentScrollController(
      initialItem: (draft.heightCm.round() - _minHeight).clamp(0, _maxHeight - _minHeight),
    );
    _weightCtrl = FixedExtentScrollController(initialItem: _weightIndex(draft.weightKg));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _yearCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  FitnessProfileDraft get _draft => ref.read(onboardingProvider);

  void _patch(FitnessProfileDraft draft) => ref.read(onboardingProvider.notifier).update(draft);

  int _weightIndex(double kg) {
    final clamped = kg.clamp(_minWeight, _maxWeight);
    return ((clamped - _minWeight) / 0.5).round();
  }

  double _weightAt(int index) => _minWeight + index * 0.5;

  int get _weightCount => ((_maxWeight - _minWeight) / 0.5).round() + 1;

  Future<void> _goTo(int step) async {
    setState(() => _step = step);
    await _pageController.animateToPage(step, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  Future<void> _next() async {
    if (_step < _totalSteps - 1) {
      await _goTo(_step + 1);
      return;
    }
    await _submit();
  }

  Future<void> _selectAndNext(FitnessProfileDraft draft) async {
    HapticFeedback.selectionClick();
    _patch(draft);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (mounted) await _next();
  }

  bool _canAdvance() {
    final d = _draft;
    switch (_step) {
      case 0:
        return d.gender != null;
      case 3:
        return d.goal != null;
      case 4:
        return d.experience != null;
      default:
        return true;
    }
  }

  Future<void> _submit() async {
    final draft = _draft;
    if (!draft.canSubmit) {
      showExpressiveSnack(context: context, message: '还有必填项没选完', icon: Symbols.error_outline_rounded);
      return;
    }
    setState(() => _generating = true);
    try {
      await ref.read(fitnessProfileProvider.notifier).submit(draft.toProfile());
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      context.go(AppRoutes.home);
    } catch (error) {
      if (!mounted) return;
      setState(() => _generating = false);
      showExpressiveSnack(
        context: context,
        message: userFacingErrorMessage(error),
        icon: Symbols.error_outline_rounded,
        duration: const Duration(seconds: 8),
      );
    }
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: false,
        leading: _step > 0 && !_generating
            ? AppBarCircleButton(tooltip: '上一步', icon: Symbols.arrow_back_rounded, onPressed: () => _goTo(_step - 1))
            : null,
        title: Text('${_step + 1} / $_totalSteps'),
        actions: [
          if (!_generating) M3ETextButton(size: M3EButtonSize.sm, onPressed: _logout, child: const Text('换个账号')),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: M3ELinearWavyProgressIndicator(
            value: (_step + 1) / _totalSteps,
            // minHeight: 4,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) => setState(() => _step = index),
                  children: [
                    _GenderStep(
                      draft: draft,
                      onSelect: (g) => _selectAndNext(draft.copyWith(gender: g)),
                    ),
                    _YearStep(
                      controller: _yearCtrl,
                      onChanged: (year) => _patch(draft.copyWith(birthYear: year)),
                    ),
                    _BodyStep(
                      heightCtrl: _heightCtrl,
                      weightCtrl: _weightCtrl,
                      weightCount: _weightCount,
                      weightAt: _weightAt,
                      onHeight: (cm) => _patch(draft.copyWith(heightCm: cm.toDouble())),
                      onWeight: (kg) => _patch(draft.copyWith(weightKg: kg)),
                    ),
                    _GoalStep(
                      draft: draft,
                      onSelect: (g) => _selectAndNext(draft.copyWith(goal: g)),
                    ),
                    _ExperienceStep(
                      draft: draft,
                      onSelect: (e) => _selectAndNext(draft.copyWith(experience: e)),
                    ),
                    _InjuryStep(
                      selected: draft.injuryTags,
                      onChanged: (tags) => _patch(draft.copyWith(injuryTags: tags)),
                    ),
                    _ScheduleStep(
                      days: draft.weeklyDays,
                      minutes: draft.sessionMinutes,
                      onDays: (v) => _patch(draft.copyWith(weeklyDays: v)),
                      onMinutes: (v) => _patch(draft.copyWith(sessionMinutes: v)),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: M3EButton(
                      size: M3EButtonSize.md,
                      onPressed: _generating || !_canAdvance() ? null : () => _next(),
                      child: Text(_step == _totalSteps - 1 ? '生成我的计划' : '继续'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_generating)
            ColoredBox(
              color: cs.surface.withValues(alpha: 0.92),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [M3ECircularWavyProgressIndicator(), SizedBox(height: 20), Text('正在生成你的计划…')],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepFrame extends StatelessWidget {
  const _StepFrame({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(title, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: tt.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 28),
        child,
      ],
    );
  }
}

class _GenderStep extends StatelessWidget {
  const _GenderStep({required this.draft, required this.onSelect});

  final FitnessProfileDraft draft;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      title: '你的性别？',
      subtitle: '用于计算基础代谢；不愿透露时会用中性公式。',
      child: Column(
        children: [
          for (final entry in FitnessGender.labels.entries) ...[
            OnboardingChoiceCard(
              label: entry.value,
              selected: draft.gender == entry.key,
              onTap: () => onSelect(entry.key),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _YearStep extends StatelessWidget {
  const _YearStep({required this.controller, required this.onChanged});

  final FixedExtentScrollController controller;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final count = _maxBirthYear - _minBirthYear + 1;
    return _StepFrame(
      title: '你的出生年份？',
      subtitle: '只收年份，用来估算最大心率和恢复节奏。',
      child: SizedBox(
        height: 240,
        child: _Wheel(
          controller: controller,
          itemCount: count,
          labelAt: (i) => '${_minBirthYear + i} 年',
          onChanged: (i) => onChanged(_minBirthYear + i),
        ),
      ),
    );
  }
}

class _BodyStep extends StatelessWidget {
  const _BodyStep({
    required this.heightCtrl,
    required this.weightCtrl,
    required this.weightCount,
    required this.weightAt,
    required this.onHeight,
    required this.onWeight,
  });

  final FixedExtentScrollController heightCtrl;
  final FixedExtentScrollController weightCtrl;
  final int weightCount;
  final double Function(int index) weightAt;
  final ValueChanged<int> onHeight;
  final ValueChanged<double> onWeight;

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      title: '身高和体重',
      subtitle: '用于精准计算你的热量消耗，只留在本机和你的账号里。',
      child: SizedBox(
        height: 240,
        child: Row(
          children: [
            Expanded(
              child: _Wheel(
                controller: heightCtrl,
                itemCount: _maxHeight - _minHeight + 1,
                labelAt: (i) => '${_minHeight + i} cm',
                onChanged: (i) => onHeight(_minHeight + i),
              ),
            ),
            Expanded(
              child: _Wheel(
                controller: weightCtrl,
                itemCount: weightCount,
                labelAt: (i) {
                  final kg = weightAt(i);
                  return kg == kg.roundToDouble() ? '${kg.round()} kg' : '${kg.toStringAsFixed(1)} kg';
                },
                onChanged: (i) => onWeight(weightAt(i)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.draft, required this.onSelect});

  final FitnessProfileDraft draft;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      title: '你的健身目标？',
      subtitle: '选一个最想先达成的，计划会按它来排。',
      child: Column(
        children: [
          for (final entry in FitnessGoal.labels.entries) ...[
            OnboardingChoiceCard(
              label: entry.value,
              selected: draft.goal == entry.key,
              onTap: () => onSelect(entry.key),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ExperienceStep extends StatelessWidget {
  const _ExperienceStep({required this.draft, required this.onSelect});

  final FitnessProfileDraft draft;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      title: '你的运动经验？',
      subtitle: '决定起步强度和动作复杂度，之后随时能改。',
      child: Column(
        children: [
          for (final entry in FitnessExperience.labels.entries) ...[
            OnboardingChoiceCard(
              label: entry.value,
              hint: FitnessExperience.hints[entry.key],
              selected: draft.experience == entry.key,
              onTap: () => onSelect(entry.key),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _InjuryStep extends StatelessWidget {
  const _InjuryStep({required this.selected, required this.onChanged});

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      title: '有没有需要避开的伤病？',
      subtitle: '会过滤容易加重伤处的动作。没有就选「无」。',
      child: Column(
        children: [
          OnboardingChoiceCard(label: '无', selected: selected.isEmpty, onTap: () => onChanged(const [])),
          const SizedBox(height: 12),
          for (final entry in FitnessInjury.labels.entries) ...[
            OnboardingChoiceCard(
              label: entry.value,
              selected: selected.contains(entry.key),
              onTap: () {
                final next = [...selected];
                if (next.contains(entry.key)) {
                  next.remove(entry.key);
                } else {
                  next.add(entry.key);
                }
                onChanged(next);
              },
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ScheduleStep extends StatelessWidget {
  const _ScheduleStep({required this.days, required this.minutes, required this.onDays, required this.onMinutes});

  final int days;
  final int minutes;
  final ValueChanged<int> onDays;
  final ValueChanged<int> onMinutes;

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      title: '每周能练几天？每次多久？',
      subtitle: '先按你现在能坚持的来，比理想计划更重要。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('每周天数', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const [2, 3, 4, 5])
                ChoiceChip(
                  label: Text(option == 5 ? '5+' : '$option'),
                  selected: days == option,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    onDays(option);
                  },
                ),
            ],
          ),
          const SizedBox(height: 28),
          Text('每次时长', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const [15, 30, 45, 60])
                ChoiceChip(
                  label: Text(option == 60 ? '60+ 分钟' : '$option 分钟'),
                  selected: minutes == option,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    onMinutes(option);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({required this.controller, required this.itemCount, required this.labelAt, required this.onChanged});

  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int index) labelAt;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 44,
      magnification: 1.08,
      squeeze: 1.1,
      useMagnifier: true,
      onSelectedItemChanged: (index) {
        HapticFeedback.selectionClick();
        onChanged(index);
      },
      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(background: cs.primaryContainer.withValues(alpha: 0.45)),
      children: [
        for (var i = 0; i < itemCount; i++)
          Center(child: Text(labelAt(i), style: Theme.of(context).textTheme.titleMedium)),
      ],
    );
  }
}
