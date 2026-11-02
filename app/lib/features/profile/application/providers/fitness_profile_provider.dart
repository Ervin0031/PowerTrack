import 'dart:convert';

import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:app_flutter/features/profile/data/repositories/profile_repository.dart';
import 'package:app_flutter/features/profile/domain/entities/fitness_profile.dart';
import 'package:app_flutter/features/profile/domain/entities/weight_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _draftKey = 'onboarding.draft';
const _completeKey = 'fitness.profile.complete';

class FitnessProfileStorage {
  FitnessProfileStorage(this._prefs);

  final SharedPreferences _prefs;

  bool get isComplete => _prefs.getBool(_completeKey) ?? false;

  Future<void> markComplete() => _prefs.setBool(_completeKey, true);

  Future<void> clearComplete() => _prefs.remove(_completeKey);

  FitnessProfileDraft? readDraft() {
    final raw = _prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return FitnessProfileDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDraft(FitnessProfileDraft draft) => _prefs.setString(_draftKey, jsonEncode(draft.toJson()));

  Future<void> clearDraft() => _prefs.remove(_draftKey);

  Future<void> clearAll() async {
    await clearComplete();
    await clearDraft();
  }
}

final fitnessProfileStorageProvider = Provider<FitnessProfileStorage>(
  (ref) => FitnessProfileStorage(ref.watch(sharedPreferencesProvider)),
);

/// 服务端档案。null = 未完成引导。
class FitnessProfileController extends AsyncNotifier<FitnessProfile?> {
  @override
  Future<FitnessProfile?> build() async {
    if (!ref.read(tokenStorageProvider).hasToken) return null;
    try {
      return await _fetchAndStore();
    } catch (_) {
      return null;
    }
  }

  Future<FitnessProfile?> _fetchAndStore() async {
    final storage = ref.read(fitnessProfileStorageProvider);
    final profile = await ref.read(fitnessProfileRepositoryProvider).fetch();
    if (profile != null) {
      await storage.markComplete();
    } else {
      await storage.clearComplete();
    }
    return profile;
  }

  /// 登录后立刻问服务器，避免换设备时被本地标记误导。
  Future<FitnessProfile?> syncFromServer() async {
    if (!ref.read(tokenStorageProvider).hasToken) {
      state = const AsyncData(null);
      return null;
    }
    state = const AsyncLoading();
    try {
      final profile = await _fetchAndStore();
      state = AsyncData(profile);
      return profile;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }

  Future<FitnessProfile> submit(FitnessProfile profile) async {
    final saved = await ref.read(fitnessProfileRepositoryProvider).upsert(profile);
    await ref.read(fitnessProfileStorageProvider).markComplete();
    await ref.read(fitnessProfileStorageProvider).clearDraft();
    state = AsyncData(saved);
    return saved;
  }

  Future<void> clearLocal() async {
    await ref.read(fitnessProfileStorageProvider).clearAll();
    state = const AsyncData(null);
  }
}

final fitnessProfileProvider =
    AsyncNotifierProvider<FitnessProfileController, FitnessProfile?>(FitnessProfileController.new);

/// 体重流水与 7 日移动平均，按窗口天数取。档案体重变化后刷新。
final weightHistoryProvider = FutureProvider.autoDispose.family<WeightHistory, int>((ref, days) {
  ref.watch(fitnessProfileProvider.select((async) => async.value?.weightKg));
  return ref.read(fitnessProfileRepositoryProvider).fetchWeightHistory(days: days);
});

/// 引导草稿：每步写入本地，防止中途退出丢失。
class OnboardingController extends Notifier<FitnessProfileDraft> {
  @override
  FitnessProfileDraft build() {
    final stored = ref.read(fitnessProfileStorageProvider).readDraft();
    if (stored != null) return stored;
    final existing = ref.read(fitnessProfileProvider).value;
    if (existing != null) return FitnessProfileDraft.fromProfile(existing);
    return const FitnessProfileDraft();
  }

  void update(FitnessProfileDraft draft) {
    state = draft;
    ref.read(fitnessProfileStorageProvider).saveDraft(draft);
  }
}

final onboardingProvider = NotifierProvider<OnboardingController, FitnessProfileDraft>(OnboardingController.new);
