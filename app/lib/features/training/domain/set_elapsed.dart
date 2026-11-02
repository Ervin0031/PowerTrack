/// 一组的耗时：从这组真正开始，到点完成。
///
/// 动作刚加进列表时写下的 [startedAt] 不能当成开始。后面若已经完成过别的组，
/// 耗时改从最近一次完成算起，避免一次加入多个动作后，练到它时变成整场时长。
int? setElapsedSeconds({
  required DateTime? startedAt,
  required DateTime now,
  required Iterable<DateTime?> otherCompletedAt,
}) {
  DateTime? latest;
  for (final at in otherCompletedAt) {
    if (at == null) continue;
    if (latest == null || at.isAfter(latest)) latest = at;
  }
  var anchor = startedAt;
  if (latest != null && (anchor == null || !anchor.isAfter(latest))) {
    anchor = latest;
  }
  if (anchor == null) return null;
  final seconds = now.difference(anchor).inSeconds;
  return seconds < 0 ? 0 : seconds;
}
