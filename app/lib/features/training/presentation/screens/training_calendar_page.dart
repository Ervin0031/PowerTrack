import 'package:app_flutter/core/network/error_message.dart';
import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/dynamic/domain/workout_feed.dart' show generateWorkoutTitle;
import 'package:app_flutter/features/training/application/providers/training_calendar_provider.dart';
import 'package:app_flutter/features/training/domain/entities/session_record.dart';
import 'package:flutter/material.dart' as flutter_material;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paged_vertical_calendar/paged_vertical_calendar.dart';

/// 日历库里的水波纹走 Flutter 的 Theme。ThemeData 很重，只建一次。
final _inkTheme = flutter_material.ThemeData(
  splashFactory: flutter_material.NoSplash.splashFactory,
  highlightColor: const Color(0x00000000),
);

const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];
const _weekdayNames = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];

/// 训练日历：月份上下铺开滚动，点选查看当日会话。
class TrainingCalendarPage extends ConsumerStatefulWidget {
  const TrainingCalendarPage({super.key});

  @override
  ConsumerState<TrainingCalendarPage> createState() => _TrainingCalendarPageState();
}

class _TrainingCalendarPageState extends ConsumerState<TrainingCalendarPage> {
  late DateTime _selectedDay;
  late DateTime _anchor;
  var _calendarGeneration = 0;
  var _calendarReady = false;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _anchor = _selectedDay;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      _calendarReady = true;
      return;
    }
    animation.addStatusListener(_onRouteStatus);
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    if (mounted) setState(() => _calendarReady = true);
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    super.dispose();
  }

  DateTime get _minDate {
    final now = DateTime.now();
    return DateTime(now.year - 1, now.month, 1);
  }

  DateTime get _maxDate {
    final now = DateTime.now();
    final last = DateTime(now.year, now.month + 1, 0);
    return DateTime(last.year, last.month, last.day, 23, 59, 59);
  }

  List<SessionRecord> _eventsForDay(Map<DateTime, List<SessionRecord>> byDay, DateTime day) {
    return byDay[DateTime(day.year, day.month, day.day)] ?? const [];
  }

  int _monthCount(Map<DateTime, List<SessionRecord>> byDay, DateTime month) {
    var count = 0;
    for (final entry in byDay.entries) {
      if (entry.key.year == month.year && entry.key.month == month.month) {
        count += entry.value.length;
      }
    }
    return count;
  }

  void _goToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _selectedDay = today;
      _anchor = today;
      _calendarGeneration++;
    });
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _dayCell(DateTime day, {bool selected = false, bool today = false, bool trained = false}) {
    final cs = Theme.of(context).colorScheme;
    final fg = selected
        ? cs.onPrimary
        : today
        ? cs.primary
        : cs.onSurface;
    return Center(
      child: SizedBox(
        width: 40,
        height: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? cs.primary : null,
            border: today && !selected ? Border.all(color: cs.primary, width: 1.5) : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '${day.day}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: fg,
                  fontWeight: trained || selected || today ? FontWeight.w600 : null,
                ),
              ),
              if (trained)
                Positioned(
                  bottom: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? cs.onPrimary : cs.primary),
                    child: const SizedBox.square(dimension: 5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final async = ref.watch(trainingCalendarProvider);

    final today = DateTime.now();
    final onToday = _sameDay(_selectedDay, today);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('训练日历'),
        actions: [if (!onToday) M3ETextButton(onPressed: _goToday, child: const Text('回到今天'))],
      ),
      body: Column(
        children: [
          SizedBox(height: context.appBarInset),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Row(
              children: [
                for (final label in _weekdayLabels)
                  Expanded(
                    child: Text(label, textAlign: TextAlign.center, style: tt.labelLarge),
                  ),
              ],
            ),
          ),
          Divider(),
          Expanded(
            child: RepaintBoundary(
              child: _calendarReady && async.hasValue
                  ? _pagedCalendar(async.requireValue, today)
                  : _oneMonth(async.asData?.value, today),
            ),
          ),
        ],
      ),
      bottomSheet: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(16, 24, 16, context.safeBottom + 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              '${_selectedDay.month}月${_selectedDay.day}日 ${_weekdayNames[_selectedDay.weekday - 1]}',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          _daySessions(async),
        ],
      ),
    );
  }

  Widget _pagedCalendar(Map<DateTime, List<SessionRecord>> byDay, DateTime today) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return flutter_material.Theme(
      data: _inkTheme,
      child: flutter_material.Material(
        type: flutter_material.MaterialType.transparency,
        child: PagedVerticalCalendar(
          key: ValueKey(_calendarGeneration),
          minDate: _minDate,
          maxDate: _maxDate,
          initialDate: _anchor,
          invisibleMonthsThreshold: 0,
          listPadding: const EdgeInsets.symmetric(horizontal: 8),
          onDayPressed: (day) {
            setState(() {
              _selectedDay = DateTime(day.year, day.month, day.day);
            });
          },
          monthBuilder: (context, month, year) {
            final count = _monthCount(byDay, DateTime(year, month));
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: Row(
                children: [
                  Text('$year年$month月', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text(count == 0 ? '没有训练' : '$count 次', style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            );
          },
          dayBuilder: (context, day) {
            return _dayCell(
              day,
              selected: _sameDay(day, _selectedDay),
              today: _sameDay(day, today),
              trained: _eventsForDay(byDay, day).isNotEmpty,
            );
          },
        ),
      ),
    );
  }

  Widget _oneMonth(Map<DateTime, List<SessionRecord>>? byDay, DateTime today) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final month = DateTime(_selectedDay.year, _selectedDay.month);
    final firstWeekday = month.weekday;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = firstWeekday - 1 + days;
    final rows = (cells / 7).ceil();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Text('${month.year}年${month.month}月', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(child: _oneMonthDay(byDay, today, month, row * 7 + column - (firstWeekday - 1))),
            ],
          ),
        if (byDay == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Text('正在读取训练记录', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
      ],
    );
  }

  Widget _oneMonthDay(Map<DateTime, List<SessionRecord>>? byDay, DateTime today, DateTime month, int day) {
    final last = DateTime(month.year, month.month + 1, 0).day;
    if (day < 1 || day > last) return const SizedBox(height: 40);
    final date = DateTime(month.year, month.month, day);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedDay = date),
      child: _dayCell(
        date,
        selected: _sameDay(date, _selectedDay),
        today: _sameDay(date, today),
        trained: byDay != null && _eventsForDay(byDay, date).isNotEmpty,
      ),
    );
  }

  Widget _daySessions(AsyncValue<Map<DateTime, List<SessionRecord>>> async) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (async.hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(userFacingErrorMessage(async.error!), style: tt.bodyMedium),
          M3ETextButton(onPressed: () => ref.invalidate(trainingCalendarProvider), child: const Text('重试')),
        ],
      );
    }
    final byDay = async.asData?.value;
    if (byDay == null) {
      return Text('正在读取训练记录', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant));
    }
    final selected = _eventsForDay(byDay, _selectedDay);
    if (selected.isEmpty) {
      return Text('这一天还没有训练', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant));
    }
    return M3ESegmentedColumn(
      color: cs.surfaceContainer,
      onTap: (index) => context.push(AppRoutes.workoutDetailOf(selected[index].id)),
      children: [for (final session in selected) _SessionRow(session: session)],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final SessionRecord session;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final time = DateFormat('HH:mm').format(session.startedAt.toLocal());
    final duration = session.duration;

    return Row(
      children: [
        M3EContainer(
          Shapes.circle,
          width: 40,
          height: 40,
          color: cs.primaryContainer,
          child: Icon(Symbols.fitness_center_rounded, size: 20, color: cs.onPrimaryContainer, fill: 1),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                generateWorkoutTitle(startedAt: session.startedAt, notes: session.notes),
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                duration == null ? '$time · 已完成' : '$time · ${formatSessionDuration(duration)}',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Icon(Symbols.chevron_right_rounded, color: cs.onSurfaceVariant),
      ],
    );
  }
}
