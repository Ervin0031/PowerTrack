/// API 日期时间：后端 TIMESTAMP 存 naive UTC，JSON 常无 `Z`；
/// Dart [DateTime.parse] 会把无时区串当成本地时间，导致展示偏 8 小时（中国）。
library;

final _naiveDateTimeRe = RegExp(
  r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(\.\d+)?$',
);

/// 是否为「带时钟、无时区」的 ISO 串（排除纯日期 `yyyy-MM-dd`）。
bool isNaiveApiDateTime(String raw) => _naiveDateTimeRe.hasMatch(raw);

/// 解析 API 时间：无时区视为 UTC；有时区则按标准解析。
DateTime parseApiDateTime(String raw) {
  final trimmed = raw.trim();
  if (isNaiveApiDateTime(trimmed)) {
    return DateTime.parse('${trimmed}Z').toUtc();
  }
  return DateTime.parse(trimmed).toUtc();
}

DateTime? parseApiDateTimeOrNull(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return parseApiDateTime(value);
}

/// 递归把响应 JSON 里的 naive datetime 补上 `Z`，让生成代码的 [DateTime.parse] 也正确。
dynamic tagNaiveUtcInJson(dynamic data) {
  if (data is Map) {
    return <String, dynamic>{
      for (final e in data.entries) e.key.toString(): tagNaiveUtcInJson(e.value),
    };
  }
  if (data is List) {
    return [for (final item in data) tagNaiveUtcInJson(item)];
  }
  if (data is String && isNaiveApiDateTime(data)) {
    return '${data}Z';
  }
  return data;
}
