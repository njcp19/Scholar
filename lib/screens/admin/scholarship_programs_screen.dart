import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/scholarship_catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/widgets.dart';

class ScholarshipProgramsScreen extends StatefulWidget {
  final ScholarshipCatalogService? catalogService;

  const ScholarshipProgramsScreen({
    super.key,
    this.catalogService,
  });

  @override
  State<ScholarshipProgramsScreen> createState() =>
      _ScholarshipProgramsScreenState();
}

class _ScholarshipProgramsScreenState extends State<ScholarshipProgramsScreen> {
  late final ScholarshipCatalogService _catalogService =
      widget.catalogService ?? ScholarshipCatalogService();

  List<ScholarshipCatalogItem> _programs = [];
  final Set<int> _savingIds = {};
  bool _loading = true;
  bool _hasLoaded = false;
  String? _loadError;

  static const _genericError = 'Something went wrong. Please try again.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final programs = await _catalogService.list(includeInactive: true);
      if (!mounted) return;
      setState(() {
        _programs = programs;
        _loadError = null;
        _loading = false;
        _hasLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = _genericError;
        _loading = false;
        _hasLoaded = true;
      });
      showMsg(context, _genericError, error: true);
    }
  }

  String _friendlyError(Object error) {
    final message = error is PostgrestException ? error.message : '';
    if (message.contains('NAME_ALREADY_EXISTS')) {
      return 'That scholarship is already on the list.';
    }
    if (message.contains('INVALID_NAME')) {
      return 'Enter a name between 2 and 80 characters.';
    }
    if (message.contains('ADMIN_ONLY')) {
      return 'Only an administrator can change this list.';
    }
    if (message.contains('NOT_FOUND')) {
      return 'That scholarship no longer exists.';
    }
    return _genericError;
  }

  Future<String?> _saveProgram(int? id, String name) async {
    try {
      if (id == null) {
        await _catalogService.add(name: name);
      } else {
        await _catalogService.rename(id: id, name: name);
      }
      return null;
    } catch (error) {
      return _friendlyError(error);
    }
  }

  Future<void> _showEditor({ScholarshipCatalogItem? program}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScholarshipProgramEditorSheet(
        initialName: program?.name,
        onSave: (name) => _saveProgram(program?.id, name),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _setProgramActive(
    ScholarshipCatalogItem program,
    bool active,
  ) async {
    if (!_savingIds.add(program.id)) return;
    setState(() {});
    try {
      await _catalogService.setActive(id: program.id, active: active);
      await _load();
    } catch (error) {
      if (mounted) showMsg(context, _friendlyError(error), error: true);
    } finally {
      if (mounted) {
        setState(() => _savingIds.remove(program.id));
      }
    }
  }

  Widget _programCard(ScholarshipCatalogItem program) {
    final saving = _savingIds.contains(program.id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: const TextStyle(
                    color: Color(0xFF1A2530),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  program.isActive ? 'Shown in Sign up' : 'Hidden',
                  style: TextStyle(
                    color: program.isActive
                        ? context.colors.successText
                        : context.colors.textBody,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Rename scholarship',
            child: SizedBox(
              width: 44,
              height: 44,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: saving ? null : () => _showEditor(program: program),
                  customBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE3E8EF)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        AppIcons.edit,
                        size: 20,
                        color: context.colors.brand,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label:
                '${program.isActive ? 'Hide' : 'Show'} ${program.name} in Sign up',
            child: Switch.adaptive(
              value: program.isActive,
              onChanged: saving
                  ? null
                  : (active) => _setProgramActive(program, active),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bodyContent() {
    if (!_hasLoaded || _loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return ErrorCard(
        message: _loadError!,
        onRetry: _load,
      );
    }
    if (_programs.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        radius: 22,
        borderColor: context.colors.borderSoft,
        child: Column(
          children: [
            Text(
              'No scholarships yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add the scholarships students can choose from.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textBody,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('SCHOLARSHIPS (${_programs.length})'),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.all(16),
          radius: 22,
          shadow: true,
          backgroundColor: Colors.white,
          borderColor: const Color(0xFFEEF1F6),
          child: Column(
            children: [
              for (var index = 0; index < _programs.length; index++) ...[
                if (index > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFEEF1F6),
                  ),
                _programCard(_programs[index]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Material(
            color: context.colors.surface,
            shape: CircleBorder(
              side: BorderSide(color: context.colors.borderSoft),
            ),
            child: IconButton(
              onPressed: () => Navigator.maybePop(context),
              tooltip: 'Back',
              constraints: const BoxConstraints.tightFor(
                width: 42,
                height: 42,
              ),
              padding: EdgeInsets.zero,
              icon: Icon(AppIcons.back, color: context.colors.textPrimary),
            ),
          ),
        ),
        title: Text(
          'Scholarship Programs',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: const [SizedBox(width: 70)],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.colors.brandTint,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Text(
                    'Students pick from this list when they sign up. '
                    'Turning one off hides it from new sign-ups; existing '
                    'scholars keep theirs.',
                    style: TextStyle(
                      color: context.colors.brand,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _bodyContent(),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: PrimaryButton(
                label: 'Add scholarship',
                onPressed: () => _showEditor(),
                minHeight: 56,
                borderRadius: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScholarshipProgramEditorSheet extends StatefulWidget {
  final String? initialName;
  final Future<String?> Function(String name) onSave;

  const _ScholarshipProgramEditorSheet({
    required this.initialName,
    required this.onSave,
  });

  @override
  State<_ScholarshipProgramEditorSheet> createState() =>
      _ScholarshipProgramEditorSheetState();
}

class _ScholarshipProgramEditorSheetState
    extends State<_ScholarshipProgramEditorSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2 || name.length > 80) {
      showMsg(
        context,
        'Enter a name between 2 and 80 characters.',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    final error = await widget.onSave(name);
    if (!mounted) return;
    if (error != null) {
      setState(() => _saving = false);
      showMsg(context, error, error: true);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final editing = widget.initialName != null;
    return PopScope(
      canPop: !_saving,
      child: AppBottomSheet(
        title: editing ? 'Rename scholarship' : 'Add scholarship',
        showDragHandle: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Use the official name, as students know it.',
              style: TextStyle(
                color: colors.textBody,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Scholarship name',
              style: TextStyle(
                color: colors.textLabel,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              autofocus: true,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. the official program name',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.brand, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '2 to 80 characters. Each name can be listed once.',
              style: TextStyle(
                color: colors.textBody,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Cancel',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    minHeight: 52,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Save',
                    onPressed: _saving ? null : _save,
                    loading: _saving,
                    minHeight: 52,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
