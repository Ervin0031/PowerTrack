import 'package:app_flutter/features/exercises/domain/entities/exercise.dart';

const _bodyweightNamesZh = {'自重', '徒手'};
const _bodyweightNamesEn = {'bodyweight'};

/// 是否按徒手/自重计负荷。
///
/// 数据库没有独立的「徒手 / 器械 / 双手」字段；后端约定自重动作
/// `equipment_id` 可留空，器械表另有「自重 / Bodyweight」。
bool isBodyweightEquipment({
  int? equipmentId,
  String? name,
  String? nameEn,
}) {
  final zh = (name ?? '').trim();
  final en = (nameEn ?? '').trim().toLowerCase();
  if (_bodyweightNamesZh.contains(zh) || _bodyweightNamesEn.contains(en)) {
    return true;
  }
  return equipmentId == null && zh.isEmpty && en.isEmpty;
}

/// 用器械目录把 [equipmentId] 解析成是否徒手。
///
/// 目录里找不到该 id 时按「器械动作」处理，避免把杠铃误填成自重。
bool isBodyweightByCatalog(int? equipmentId, Iterable<Equipment> catalog) {
  if (equipmentId == null) return true;
  for (final item in catalog) {
    if (item.id == equipmentId) {
      return isBodyweightEquipment(
        equipmentId: item.id,
        name: item.name,
        nameEn: item.nameEn,
      );
    }
  }
  return false;
}
