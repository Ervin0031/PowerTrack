import 'package:app_flutter/features/dynamic/domain/entities/workout_feed_item.dart';
import 'package:flutter_muscle_anatomy/flutter_muscle_anatomy.dart';

/// 后端肌群中英文名 → 解剖图肌肉。未知肌群不画，避免模糊匹配画错部位。
///
/// 库里没有竖脊肌路径，下背 / 竖脊肌刻意留空，不要错映到斜方或腘绳肌。
const _groupMuscles = <String, List<Muscle>>{
  'chest': _pecs,
  'pecs': _pecs,
  'pec': _pecs,
  'pectoral': _pecs,
  'pectorals': _pecs,
  'upper chest': _pecs,
  'lower chest': _pecs,
  '胸部': _pecs,
  '上胸部': _pecs,
  '下胸部': _pecs,
  'lats': _lats,
  'lat': _lats,
  '背阔肌': _lats,
  'back': _back,
  '背部': _back,
  'upper back': _traps,
  '上背部': _traps,
  'traps': _traps,
  'trap': _traps,
  '斜方肌': _traps,
  'shoulders': _shoulders,
  'shoulder': _shoulders,
  'delts': _shoulders,
  '肩部': _shoulders,
  '肩膀': _shoulders,
  'front delts': _frontDelts,
  'front delt': _frontDelts,
  'anterior deltoid': _frontDelts,
  '三角肌前束': _frontDelts,
  'side delts': _sideDelts,
  'side delt': _sideDelts,
  'lateral deltoid': _sideDelts,
  '三角肌中束': _sideDelts,
  'rear delts': _rearDelts,
  'rear delt': _rearDelts,
  'posterior deltoid': _rearDelts,
  '三角肌后束': _rearDelts,
  'biceps': _biceps,
  'bicep': _biceps,
  '肱二头肌': _biceps,
  'triceps': _triceps,
  'tricep': _triceps,
  '肱三头肌': _triceps,
  'forearms': _forearms,
  'forearm': _forearms,
  '前臂': _forearms,
  'abs': _abs,
  'ab': _abs,
  'core': _abs,
  'rectus abdominis': _abs,
  '腹肌': _abs,
  '腹直肌': _abs,
  '核心整体': _abs,
  'obliques': _obliques,
  'oblique': _obliques,
  '腹斜肌': _obliques,
  'quads': _quads,
  'quad': _quads,
  'quadriceps': _quads,
  '股四头肌': _quads,
  'hamstrings': _hamstrings,
  'hamstring': _hamstrings,
  '腘绳肌': _hamstrings,
  'glutes': _glutes,
  'glute': _glutes,
  '臀部': _glutes,
  'calves': _calves,
  'calf': _calves,
  '小腿': _calves,
  'hip flexors': _hipFlexors,
  'hip flexor': _hipFlexors,
  '髋屈肌': _hipFlexors,
  'adductors': _adductors,
  'adductor': _adductors,
  '内收肌': _adductors,
  'abductors': _abductors,
  'abductor': _abductors,
  '外展肌': _abductors,
  'shins': _shins,
  'shin': _shins,
  'tibialis anterior': _shins,
  '胫骨前肌': _shins,
  'lower back': _none,
  '下背部': _none,
  'erector spinae': _none,
  '竖脊肌': _none,
};

const _none = <Muscle>[];
const _pecs = [Muscle.pectoralisMajor];
const _lats = [Muscle.latissimusDorsi];
const _traps = [Muscle.trapezius, Muscle.upperTrapezius];
const _back = [Muscle.latissimusDorsi, Muscle.trapezius];
const _shoulders = [Muscle.deltoid, Muscle.anteriorDeltoid, Muscle.posteriorDeltoid];
/// 男模 SVG 只有 `deltoid`，女模才有 `anterior_deltoid`，两边都点以免漏画。
const _frontDelts = [Muscle.anteriorDeltoid, Muscle.deltoid];
const _sideDelts = [Muscle.deltoid];
const _rearDelts = [Muscle.posteriorDeltoid];
const _biceps = [Muscle.biceps, Muscle.brachialis];
const _triceps = [Muscle.triceps];
const _forearms = [
  Muscle.brachioradialis,
  Muscle.flexorCarpiUlnaris,
  Muscle.extensorCarpiUlnaris,
  Muscle.extensorDigitorum,
  Muscle.pronatorTeres,
];
const _abs = [Muscle.rectusAbdominis];
const _obliques = [Muscle.externalOblique, Muscle.externalAbdominalOblique];
const _quads = [Muscle.rectusFemoris, Muscle.vastusMedialis, Muscle.vastusLateralis];
const _hamstrings = [Muscle.bicepsFemoris, Muscle.semitendinosus, Muscle.semimembranosus];
const _glutes = [Muscle.gluteusMaximus, Muscle.gluteusMedius];
const _calves = [Muscle.gastrocnemius, Muscle.soleus];
const _hipFlexors = [Muscle.iliopsoas, Muscle.tensorFasciaeLatae, Muscle.flexorFasciaeLatae];
const _adductors = [Muscle.adductorLongus, Muscle.adductorMagnus, Muscle.gracilis, Muscle.pectineus];
const _abductors = [Muscle.gluteusMedius];
const _shins = [Muscle.tibialisAnterior];

List<Muscle> musclesForHit(WorkoutMuscleHit hit) {
  for (final key in _lookupKeys(hit)) {
    final muscles = _groupMuscles[key];
    if (muscles != null) return muscles;
  }
  return const [];
}

bool isChestHit(WorkoutMuscleHit hit) => musclesForHit(hit).contains(Muscle.pectoralisMajor);

Iterable<String> _lookupKeys(WorkoutMuscleHit hit) sync* {
  final en = hit.nameEn.trim().toLowerCase();
  if (en.isNotEmpty) yield en;
  final name = hit.name.trim();
  if (name.isNotEmpty) {
    yield name.toLowerCase();
    yield name;
  }
}
