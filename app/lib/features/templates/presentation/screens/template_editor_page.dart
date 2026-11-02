import 'dart:io';

import 'package:app_flutter/core/network/error_message.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/templates/application/providers/templates_provider.dart';
import 'package:app_flutter/features/templates/domain/entities/workout_template.dart';
import 'package:app_flutter/features/training/application/exercise_editor.dart';
import 'package:app_flutter/features/training/application/providers/active_set_edit_provider.dart';
import 'package:app_flutter/features/training/application/exercise_editor_providers.dart';
import 'package:app_flutter/features/training/presentation/screens/exercise_picker_page.dart';
import 'package:app_flutter/features/training/presentation/widgets/edit_bar.dart';
import 'package:app_flutter/features/training/presentation/widgets/session_exercise_list.dart';
import 'package:app_flutter/shared/widgets/app_network_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 用独立 ProviderScope 把动作卡片切到模板草稿。
class TemplateEditorScope extends ConsumerWidget {
  const TemplateEditorScope({super.key, this.templateId});

  final int? templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        exerciseEditorKindProvider.overrideWithValue(
          ExerciseEditorKind.template,
        ),
        exerciseListEditorProvider.overrideWith(
          (ref) => ref.read(templateDraftProvider.notifier),
        ),
        focusedExerciseIdProvider.overrideWith(
          (ref) => ref.watch(
            templateDraftProvider.select((s) => s.focusedExerciseId),
          ),
        ),
        editorExerciseIdsProvider.overrideWith(
          (ref) => ref.watch(
            templateDraftProvider.select(
              (s) => s.exercises.map((e) => e.exerciseId).toSet(),
            ),
          ),
        ),
      ],
      child: TemplateEditorPage(templateId: templateId),
    );
  }
}

class TemplateEditorPage extends ConsumerStatefulWidget {
  const TemplateEditorPage({super.key, this.templateId});

  final int? templateId;

  @override
  ConsumerState<TemplateEditorPage> createState() => _TemplateEditorPageState();
}

class _TemplateEditorPageState extends ConsumerState<TemplateEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  var _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _description = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final id = widget.templateId;
    if (id == null) {
      ref.read(templateDraftProvider.notifier).reset();
      return;
    }
    setState(() => _loadingDetail = true);
    try {
      final detail = await ref.read(templateDetailProvider(id).future);
      if (!mounted) return;
      ref.read(templateDraftProvider.notifier).load(detail);
      _title.text = detail.title;
      _description.text = detail.description ?? '';
    } catch (error) {
      if (mounted) {
        showExpressiveSnack(
          context: context,
          message: userFacingErrorMessage(error),
          icon: Symbols.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    ref.read(templateDraftProvider.notifier).setCoverPath(picked.path);
  }

  Future<void> _save() async {
    ref.read(templateDraftProvider.notifier).setTitle(_title.text);
    ref.read(templateDraftProvider.notifier).setDescription(_description.text);
    try {
      final saved = await ref.read(templateDraftProvider.notifier).save();
      ref.invalidate(templatesProvider);
      ref.invalidate(templateDetailProvider(saved.id));
      if (!mounted) return;
      showExpressiveSnack(
        context: context,
        message: '已保存',
        icon: Symbols.check_rounded,
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      showExpressiveSnack(
        context: context,
        message: userFacingErrorMessage(error),
        icon: Symbols.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(templateDraftProvider);
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final editingSet = ref.watch(activeSetEditNotifierProvider) != null;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(
        title: Text(draft.isEditing ? '修改模板' : '新建模板'),
        actions: [M3EButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: _loadingDetail
          ? const Center(child: M3ELoadingIndicator())
          : Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          context.appBarInset + 8,
                          16,
                          12,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GestureDetector(
                                onTap: _pickCover,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: _Cover(
                                      path: draft.coverPath,
                                      url: draft.coverUrl,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _title,
                                decoration: const InputDecoration(
                                  filled: true,
                                  labelText: '标题',
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide.none,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(AppRadius.card),
                                    ),
                                  ),
                                ),
                                onChanged: ref
                                    .read(templateDraftProvider.notifier)
                                    .setTitle,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _description,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  filled: true,
                                  labelText: '说明',
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide.none,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(AppRadius.card),
                                    ),
                                  ),
                                ),
                                onChanged: ref
                                    .read(templateDraftProvider.notifier)
                                    .setDescription,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '难度',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final d in TemplateDifficulty.values)
                                    M3EButton(
                                      style: draft.difficulty == d
                                          ? M3EButtonStyle.filled
                                          : M3EButtonStyle.tonal,
                                      size: M3EButtonSize.sm,
                                      onPressed: () => ref
                                          .read(templateDraftProvider.notifier)
                                          .setDifficulty(d),
                                      child: Text(d.label),
                                    ),
                                ],
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('公开'),
                                subtitle: Text(
                                  draft.isPublic ? '其他用户可以看见并使用' : '只有你自己能看见',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                                value: draft.isPublic,
                                onChanged: ref
                                    .read(templateDraftProvider.notifier)
                                    .setPublic,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '动作',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (draft.exercises.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: Text('点击下方 + 添加动作')),
                        )
                      else
                        SliverToBoxAdapter(
                          child: SessionExerciseList(
                            exercises: draft.exercises,
                            shrinkWrap: true,
                          ),
                        ),

                      SliverPadding(
                        padding: EdgeInsetsGeometry.only(
                          bottom: context.safeBottom,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: keyboardVisible && editingSet
                      ? const EditBar(key: ValueKey('edit-bar'))
                      : const SizedBox.shrink(key: ValueKey('edit-bar-empty')),
                ),
              ],
            ),
      floatingActionButton: keyboardVisible
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
              ),
              child: FloatingActionButton(
                onPressed: () => showExercisePicker(context),
                child: const Icon(Symbols.add_rounded),
              ),
            ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({this.path, this.url});

  final String? path;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (path != null) {
      return Image.file(File(path!), fit: BoxFit.cover);
    }
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url!,
        // 封面 URL 仍是 presigned（签名每次不同），剥离签名才能命中磁盘缓存。
        cacheKey: stableImageCacheKey(url!),
        fit: BoxFit.cover,
        placeholder: (_, _) => ColoredBox(color: cs.surfaceContainerHighest),
        errorWidget: (_, _, _) => ColoredBox(color: cs.surfaceContainerHighest),
      );
    }
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.add_photo_alternate_rounded,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              '添加封面',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
