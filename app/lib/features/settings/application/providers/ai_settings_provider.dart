import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:app_flutter/features/settings/data/repositories/ai_settings_repository.dart';
import 'package:app_flutter/features/settings/domain/entities/ai_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final aiSettingsRepositoryProvider = Provider<AiSettingsRepository>(
  (ref) => AiSettingsRepository(ref.watch(sharedPreferencesProvider)),
);

final aiSettingsProvider =
    AsyncNotifierProvider<AiSettingsController, AiSettings>(
  AiSettingsController.new,
);

class AiSettingsController extends AsyncNotifier<AiSettings> {
  @override
  Future<AiSettings> build() => ref.watch(aiSettingsRepositoryProvider).load();

  Future<void> save({
    required String baseUrl,
    required String model,
    String? apiKey,
  }) async {
    final repo = ref.read(aiSettingsRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repo.save(baseUrl: baseUrl, model: model, apiKey: apiKey);
      return repo.load();
    });
  }

  Future<void> clearApiKey() async {
    final repo = ref.read(aiSettingsRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repo.clearApiKey();
      return repo.load();
    });
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(aiSettingsRepositoryProvider).load(),
    );
  }
}
