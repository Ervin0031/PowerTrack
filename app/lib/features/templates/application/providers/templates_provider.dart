import 'dart:math';

import 'package:app_flutter/features/exercises/domain/bodyweight.dart';
import 'package:app_flutter/features/exercises/domain/entities/exercise.dart';
import 'package:app_flutter/features/templates/data/repositories/template_repository.dart';
import 'package:app_flutter/features/templates/domain/entities/workout_template.dart';
import 'package:app_flutter/features/training/application/bodyweight_defaults.dart';
import 'package:app_flutter/features/training/application/exercise_editor.dart';
import 'package:app_flutter/features/training/domain/bodyweight_load.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/features/training/domain/entities/training_set_kind.dart';
import 'package:app_flutter/features/training/domain/new_set_defaults.dart';
import 'package:app_flutter/features/training/domain/rpe.dart';
import 'package:app_flutter/features/training/domain/set_follow.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _pageSize = 8;

class TemplatesFilter {
  const TemplatesFilter({
    this.search = '',
    this.scope = 'all',
    this.difficulty,
    this.muscleGroupId,
    this.equipmentId,
  });

  final String search;
  final String scope;
  final TemplateDifficulty? difficulty;
  final int? muscleGroupId;
  final int? equipmentId;

  TemplatesFilter copyWith({
    String? search,
    String? scope,
    TemplateDifficulty? difficulty,
    bool clearDifficulty = false,
    int? muscleGroupId,
    bool clearMuscleGroup = false,
    int? equipmentId,
    bool clearEquipment = false,
  }) {
    return TemplatesFilter(
      search: search ?? this.search,
      scope: scope ?? this.scope,
      difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
      muscleGroupId: clearMuscleGroup ? null : (muscleGroupId ?? this.muscleGroupId),
      equipmentId: clearEquipment ? null : (equipmentId ?? this.equipmentId),
    );
  }
}

final templatesFilterProvider = StateProvider<TemplatesFilter>((ref) => const TemplatesFilter());

class TemplatesPageState {
  const TemplatesPageState({
    this.items = const [],
    this.skip = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    required this.filter,
  });

  final List<WorkoutTemplate> items;
  final int skip;
  final bool hasMore;
  final bool isLoadingMore;
  final TemplatesFilter filter;

  TemplatesPageState copyWith({
    List<WorkoutTemplate>? items,
    int? skip,
    bool? hasMore,
    bool? isLoadingMore,
    TemplatesFilter? filter,
  }) {
    return TemplatesPageState(
      items: items ?? this.items,
      skip: skip ?? this.skip,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      filter: filter ?? this.filter,
    );
  }
}

class TemplatesController extends AsyncNotifier<TemplatesPageState> {
  @override
  Future<TemplatesPageState> build() async {
    final filter = ref.watch(templatesFilterProvider);
    final page = await _fetch(filter, skip: 0);
    return TemplatesPageState(
      items: page.items,
      skip: page.items.length,
      hasMore: page.items.length >= _pageSize,
      filter: filter,
    );
  }

  Future<void> refresh() async {
    final filter = ref.read(templatesFilterProvider);
    try {
      final page = await _fetch(filter, skip: 0);
      state = AsyncData(
        TemplatesPageState(
          items: page.items,
          skip: page.items.length,
          hasMore: page.items.length >= _pageSize,
          filter: filter,
        ),
      );
    } catch (error, stackTrace) {
      if (state.value == null) state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await _fetch(current.filter, skip: current.skip);
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(
        latest.copyWith(
          items: [...latest.items, ...page.items],
          skip: latest.skip + page.items.length,
          hasMore: page.items.length >= _pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      final latest = state.value;
      if (latest != null) state = AsyncData(latest.copyWith(isLoadingMore: false));
    }
  }

  Future<TemplatePage> _fetch(TemplatesFilter filter, {required int skip}) {
    return ref.read(templateRepositoryProvider).listTemplates(
          search: filter.search,
          difficulty: filter.difficulty?.apiValue,
          muscleGroupId: filter.muscleGroupId,
          equipmentId: filter.equipmentId,
          scope: filter.scope,
          skip: skip,
          limit: _pageSize,
        );
  }

  Future<void> deleteTemplate(int id) async {
    await ref.read(templateRepositoryProvider).deleteTemplate(id);
    await refresh();
  }
}

final templatesProvider = AsyncNotifierProvider<TemplatesController, TemplatesPageState>(
  TemplatesController.new,
);

final templateDetailProvider = FutureProvider.autoDispose.family<WorkoutTemplate, int>((ref, id) {
  return ref.watch(templateRepositoryProvider).getTemplate(id);
});

class TemplateCompletionsState {
  const TemplateCompletionsState({
    this.items = const [],
    this.skip = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<TemplateCompletion> items;
  final int skip;
  final bool hasMore;
  final bool isLoadingMore;

  TemplateCompletionsState copyWith({
    List<TemplateCompletion>? items,
    int? skip,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return TemplateCompletionsState(
      items: items ?? this.items,
      skip: skip ?? this.skip,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class TemplateCompletionsController extends FamilyAsyncNotifier<TemplateCompletionsState, int> {
  @override
  Future<TemplateCompletionsState> build(int arg) async {
    final page = await ref.read(templateRepositoryProvider).listCompletions(arg, skip: 0, limit: _pageSize);
    return TemplateCompletionsState(
      items: page.items,
      skip: page.items.length,
      hasMore: page.items.length >= _pageSize,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(templateRepositoryProvider).listCompletions(
            arg,
            skip: current.skip,
            limit: _pageSize,
          );
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(
        latest.copyWith(
          items: [...latest.items, ...page.items],
          skip: latest.skip + page.items.length,
          hasMore: page.items.length >= _pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      final latest = state.value;
      if (latest != null) state = AsyncData(latest.copyWith(isLoadingMore: false));
    }
  }
}

final templateCompletionsProvider =
    AsyncNotifierProvider.family<TemplateCompletionsController, TemplateCompletionsState, int>(
  TemplateCompletionsController.new,
);

class Unset {
  const Unset();
}

const unset = Unset();

class TemplateDraftState {
  const TemplateDraftState({
    this.id,
    this.title = '',
    this.description = '',
    this.difficulty = TemplateDifficulty.moderate,
    this.isPublic = false,
    this.coverUrl,
    this.coverPath,
    this.exercises = const [],
    this.focusedExerciseId,
  });

  final int? id;
  final String title;
  final String description;
  final TemplateDifficulty difficulty;
  final bool isPublic;
  final String? coverUrl;
  final String? coverPath;
  final List<TrainingExercise> exercises;
  final int? focusedExerciseId;

  bool get isEditing => id != null;

  TemplateDraftState copyWith({
    int? id,
    bool clearId = false,
    String? title,
    String? description,
    TemplateDifficulty? difficulty,
    bool? isPublic,
    String? coverUrl,
    bool clearCoverUrl = false,
    String? coverPath,
    bool clearCoverPath = false,
    List<TrainingExercise>? exercises,
    int? focusedExerciseId,
    bool clearFocused = false,
  }) {
    return TemplateDraftState(
      id: clearId ? null : (id ?? this.id),
      title: title ?? this.title,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      isPublic: isPublic ?? this.isPublic,
      coverUrl: clearCoverUrl ? null : (coverUrl ?? this.coverUrl),
      coverPath: clearCoverPath ? null : (coverPath ?? this.coverPath),
      exercises: exercises ?? this.exercises,
      focusedExerciseId: clearFocused ? null : (focusedExerciseId ?? this.focusedExerciseId),
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'title': title.trim(),
      'description': description.trim().isEmpty ? null : description.trim(),
      'difficulty': difficulty.apiValue,
      'isPublic': isPublic,
      'exercises': [
        for (var i = 0; i < exercises.length; i++)
          {
            'exerciseId': exercises[i].exerciseId,
            'sortOrder': i,
            'supersetId': exercises[i].supersetId,
            'notes': exercises[i].notes,
            'restTargetSeconds': exercises[i].restTargetSeconds,
            'weightUnit': exercises[i].weightUnit,
            'sets': [
              for (final set in exercises[i].sets)
                {
                  'setNumber': set.setNumber,
                  'reps': set.reps,
                  'weightKg': set.weightKg,
                  'durationSeconds': set.durationSeconds,
                  'distanceMeters': set.distanceMeters,
                  'notes': set.notes,
                  'setKind': set.setKind.name,
                },
            ],
          },
      ],
    };
  }
}

class TemplateDraft extends Notifier<TemplateDraftState> implements ExerciseListEditor {
  static final _random = Random();

  String _uuid() => '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32).toRadixString(16)}';

  @override
  TemplateDraftState build() => const TemplateDraftState();

  void reset() => state = const TemplateDraftState();

  void load(WorkoutTemplate template) {
    state = TemplateDraftState(
      id: template.id,
      title: template.title,
      description: template.description ?? '',
      difficulty: template.difficulty,
      isPublic: template.isPublic,
      coverUrl: template.coverUrl,
      exercises: [for (final e in template.exercises) e.toTrainingExercise()],
      focusedExerciseId: template.exercises.isEmpty ? null : template.exercises.first.exerciseId,
    );
    _hydrateBodyweight();
  }

  Future<void> _hydrateBodyweight() async {
    final bodyKg = readUserBodyweightKg(ref);
    final next = <TrainingExercise>[];
    for (final exercise in state.exercises) {
      final isBw = exercise.isBodyweight ||
          await resolveIsBodyweight(ref, exerciseId: exercise.exerciseId);
      next.add(applyBodyweightDefault(exercise.copyWith(isBodyweight: isBw), bodyKg));
    }
    state = state.copyWith(exercises: next);
  }

  void setTitle(String value) => state = state.copyWith(title: value);

  void setDescription(String value) => state = state.copyWith(description: value);

  void setDifficulty(TemplateDifficulty value) => state = state.copyWith(difficulty: value);

  void setPublic(bool value) => state = state.copyWith(isPublic: value);

  void setCoverPath(String path) => state = state.copyWith(coverPath: path);

  @override
  Future<void> addExercises(List<Exercise> exercises, {int? supersetId}) async {
    final existing = state.exercises.map((e) => e.exerciseId).toSet();
    final catalog = await loadEquipmentCatalog(ref);
    final added = <TrainingExercise>[];
    for (final e in exercises) {
      if (existing.contains(e.id)) continue;
      final isBw = isBodyweightByCatalog(e.equipmentId, catalog);
      added.add(
        TrainingExercise(
          exerciseId: e.id,
          name: e.name,
          imageUrl: e.imageUrl,
          exerciseType: e.exerciseType,
          isBodyweight: isBw,
          supersetId: supersetId,
          sets: [defaultNewTrainingSet(clientUuid: _uuid(), isBodyweight: isBw)],
        ),
      );
    }
    if (added.isEmpty) return;
    state = state.copyWith(
      exercises: [...state.exercises, ...added],
      focusedExerciseId: added.last.exerciseId,
    );
  }

  @override
  Future<bool> replaceExercise(int oldId, Exercise next) async {
    if (next.id == oldId) return true;
    if (state.exercises.any((e) => e.exerciseId == next.id)) return false;
    final idx = state.exercises.indexWhere((e) => e.exerciseId == oldId);
    if (idx < 0) return false;
    final old = state.exercises[idx];
    final isBw = isBodyweightByCatalog(next.equipmentId, await loadEquipmentCatalog(ref));
    final nextList = [...state.exercises];
    nextList[idx] = old.copyWith(
      exerciseId: next.id,
      name: next.name,
      imageUrl: next.imageUrl,
      exerciseType: next.exerciseType,
      isBodyweight: isBw,
      sets: isBw ? fillBodyweightIfMissing(old.sets, readUserBodyweightKg(ref)) : old.sets,
    );
    state = state.copyWith(
      exercises: nextList,
      focusedExerciseId: state.focusedExerciseId == oldId ? next.id : state.focusedExerciseId,
    );
    return true;
  }

  @override
  void removeExercise(int exerciseId) {
    final idx = state.exercises.indexWhere((e) => e.exerciseId == exerciseId);
    if (idx < 0) return;
    final remaining = [...state.exercises]..removeAt(idx);
    int? focused = state.focusedExerciseId;
    if (focused == exerciseId) {
      if (remaining.isEmpty) {
        focused = null;
      } else if (idx < remaining.length) {
        focused = remaining[idx].exerciseId;
      } else {
        focused = remaining.last.exerciseId;
      }
    }
    state = state.copyWith(
      exercises: remaining,
      focusedExerciseId: focused,
      clearFocused: remaining.isEmpty,
    );
  }

  @override
  void toggleExerciseExpanded(int exerciseId) {
    if (state.focusedExerciseId == exerciseId) {
      state = state.copyWith(clearFocused: true);
      return;
    }
    state = state.copyWith(focusedExerciseId: exerciseId);
  }

  @override
  void addSet(int exerciseId) {
    state = state.copyWith(
      exercises: [
        for (final e in state.exercises)
          if (e.exerciseId != exerciseId)
            e
          else
            e.copyWith(
              sets: [
                ...e.sets,
                TrainingSet(
                  setNumber: e.sets.isEmpty ? 1 : e.sets.map((s) => s.setNumber).reduce(max) + 1,
                  reps: e.sets.isEmpty ? null : e.sets.last.reps,
                  weightKg: copyOrBodyweightKg(
                    isBodyweight: e.isBodyweight,
                    previousKg: e.sets.isEmpty ? null : e.sets.last.weightKg,
                    bodyKg: e.isBodyweight ? null : readUserBodyweightKg(ref),
                  ),
                  setKind: e.sets.isEmpty ? TrainingSetKind.working : e.sets.last.setKind,
                  clientUuid: _uuid(),
                ),
              ],
            ),
      ],
    );
  }

  @override
  void removeSet(int exerciseId, int setNumber) {
    final exercise = state.exercises.where((e) => e.exerciseId == exerciseId).firstOrNull;
    if (exercise == null || exercise.sets.length <= 1) return;
    state = state.copyWith(
      exercises: [
        for (final e in state.exercises)
          if (e.exerciseId != exerciseId) e else e.copyWith(sets: e.sets.where((s) => s.setNumber != setNumber).toList()),
      ],
    );
  }

  @override
  void updateExercise(int exerciseId, {Object? notes = unset, Object? restTargetSeconds = unset, String? weightUnit}) {
    state = state.copyWith(
      exercises: [
        for (final e in state.exercises)
          if (e.exerciseId != exerciseId)
            e
          else
            e.copyWith(
              notes: notes is Unset ? e.notes : notes as String?,
              restTargetSeconds: restTargetSeconds is Unset ? e.restTargetSeconds : restTargetSeconds as int?,
              weightUnit: weightUnit ?? e.weightUnit,
            ),
      ],
    );
  }

  double? _asDouble(Object? value) {
    if (value is Unset) return null;
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return null;
  }

  @override
  void updateSet(
    int exerciseId,
    int setNumber, {
    Object? reps = unset,
    Object? weightKg = unset,
    Object? restSeconds = unset,
    Object? durationSeconds = unset,
    Object? distanceMeters = unset,
    Object? notes = unset,
    TrainingSetKind? setKind,
    Object? rpe = unset,
    Object? suggestedWeightKg = unset,
    bool followRemaining = true,
    bool followMatching = false,
  }) {
    state = state.copyWith(
      exercises: [
        for (final e in state.exercises)
          if (e.exerciseId != exerciseId)
            e
          else
            _withPatchedSet(
              e,
              setNumber,
              reps: reps,
              weightKg: weightKg,
              restSeconds: restSeconds,
              durationSeconds: durationSeconds,
              distanceMeters: distanceMeters,
              notes: notes,
              setKind: setKind,
              rpe: rpe,
              suggestedWeightKg: suggestedWeightKg,
              followRemaining: followRemaining,
              followMatching: followMatching,
            ),
      ],
    );
  }

  TrainingExercise _withPatchedSet(
    TrainingExercise e,
    int setNumber, {
    required Object? reps,
    required Object? weightKg,
    required Object? restSeconds,
    required Object? durationSeconds,
    required Object? distanceMeters,
    required Object? notes,
    required TrainingSetKind? setKind,
    required Object? rpe,
    required Object? suggestedWeightKg,
    required bool followRemaining,
    required bool followMatching,
  }) {
    final target = e.sets.where((s) => s.setNumber == setNumber).firstOrNull;
    if (target == null) return e;
    final edited = target.copyWith(
      reps: reps is Unset ? target.reps : reps as int?,
      weightKg: weightKg is Unset ? target.weightKg : _asDouble(weightKg),
      restSeconds: restSeconds is Unset ? target.restSeconds : restSeconds as int?,
      durationSeconds: durationSeconds is Unset ? target.durationSeconds : durationSeconds as int?,
      distanceMeters: distanceMeters is Unset ? target.distanceMeters : _asDouble(distanceMeters),
      notes: notes is Unset ? target.notes : notes as String?,
      setKind: setKind ?? target.setKind,
      rpe: rpe is Unset ? target.rpe : _asDouble(rpe),
      suggestedWeightKg: suggestedWeightKg is Unset ? target.suggestedWeightKg : _asDouble(suggestedWeightKg),
    );
    final followReps = reps is! Unset;
    final followWeight = weightKg is! Unset;
    return e.copyWith(
      sets: followMatching
          ? patchSetMatching(
              sets: e.sets,
              edited: edited,
              previousReps: target.reps,
              previousWeightKg: target.weightKg,
              followReps: followReps,
              followWeight: followWeight,
            )
          : patchSetAndFollow(
              sets: e.sets,
              edited: edited,
              followReps: followRemaining && followReps,
              followWeight: followRemaining && followWeight,
            ),
    );
  }

  @override
  void updateAllSets(int exerciseId, {int? reps, double? weightKg}) {
    state = state.copyWith(
      exercises: [
        for (final e in state.exercises)
          if (e.exerciseId != exerciseId)
            e
          else
            e.copyWith(
              sets: [
                for (final s in e.sets)
                  s.copyWith(
                    reps: reps ?? s.reps,
                    weightKg: weightKg ?? s.weightKg,
                  ),
              ],
            ),
      ],
    );
  }

  @override
  void applySuggestedWeight(int exerciseId, int setNumber) {}

  @override
  void toggleSetDone(int exerciseId, int setNumber) {}

  @override
  RpeFollowUp? completeSetWithRpe(int exerciseId, int setNumber, double rpe) => null;

  @override
  void reduceRemainingWeights(int exerciseId) {}

  Future<WorkoutTemplate> save() {
    final title = state.title.trim();
    if (title.isEmpty) {
      throw const FormatException('请填写标题');
    }
    return ref.read(templateRepositoryProvider).saveTemplate(
          id: state.id,
          payload: state.toPayload(),
          coverPath: state.coverPath,
        );
  }
}

final templateDraftProvider = NotifierProvider<TemplateDraft, TemplateDraftState>(TemplateDraft.new);
