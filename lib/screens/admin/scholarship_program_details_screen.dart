import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/scholarship_catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/scholarship_formatters.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/widgets.dart';

class ScholarshipProgramDetailsScreen extends StatefulWidget {
  final ScholarshipCatalogItem program;
  final ScholarshipCatalogService? catalogService;

  const ScholarshipProgramDetailsScreen({
    super.key,
    required this.program,
    this.catalogService,
  });

  @override
  State<ScholarshipProgramDetailsScreen> createState() =>
      _ScholarshipProgramDetailsScreenState();
}

class _ScholarshipProgramDetailsScreenState
    extends State<ScholarshipProgramDetailsScreen> {
  late final ScholarshipCatalogService _catalogService =
      widget.catalogService ?? ScholarshipCatalogService();
  late final TextEditingController _description =
      TextEditingController(text: widget.program.description ?? '');
  late final TextEditingController _allowance = TextEditingController(
    text: widget.program.allowanceAmount?.toStringAsFixed(2) ?? '',
  );
  final TextEditingController _programBudget = TextEditingController();
  late final TextEditingController _slots = TextEditingController(
    text: widget.program.slots?.toString() ?? '',
  );
  late String? _payoutFrequency = widget.program.payoutFrequency;
  late int? _supportFromYear = widget.program.supportFromYear;
  late int? _supportToYear = widget.program.supportToYear;
  bool _saving = false;
  double _budgetUsed = 0;
  double? _budgetRemaining;
  String? _supportError;
  String? _allowanceError;
  String? _programBudgetError;
  String? _slotsError;

  @override
  void initState() {
    super.initState();
    _loadProgramBudget();
  }

  @override
  void dispose() {
    _description.dispose();
    _allowance.dispose();
    _programBudget.dispose();
    _slots.dispose();
    super.dispose();
  }

  Future<void> _loadProgramBudget() async {
    try {
      final budgets = await _catalogService.getProgramBudgets();
      final budget = budgets.where(
        (item) => item.programName == widget.program.name,
      );
      if (budget.isEmpty || !mounted) return;
      final item = budget.first;
      setState(() {
        _programBudget.text = item.programBudget?.toStringAsFixed(2) ?? '';
        _budgetUsed = item.budgetUsed;
        _budgetRemaining = item.budgetRemaining;
      });
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          error is ScholarshipCatalogException
              ? error.message
              : 'Could not load program budget.',
          type: AppSnackBarType.error,
        );
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final allowanceText = _allowance.text.trim().replaceAll(',', '');
    final allowanceAmount =
        allowanceText.isEmpty ? null : double.tryParse(allowanceText);
    final budgetText = _programBudget.text.trim().replaceAll(',', '');
    final programBudget =
        budgetText.isEmpty ? null : double.tryParse(budgetText);
    final slotsText = _slots.text.trim();
    final slots = slotsText.isEmpty ? null : int.tryParse(slotsText);
    final supportError = _supportFromYear != null &&
            _supportToYear != null &&
            _supportToYear! < _supportFromYear!
        ? 'End year cannot be before start year.'
        : null;
    final allowanceError = allowanceText.isNotEmpty && allowanceAmount == null
        ? 'Enter a valid allowance amount.'
        : null;
    final programBudgetError =
        budgetText.isNotEmpty && (programBudget == null || programBudget < 0)
            ? 'Enter a valid budget greater than or equal to zero.'
            : null;
    final slotsError = slotsText.isNotEmpty && (slots == null || slots < 0)
        ? 'Enter a whole number of slots greater than or equal to zero.'
        : null;
    setState(() {
      _supportError = supportError;
      _allowanceError = allowanceError;
      _programBudgetError = programBudgetError;
      _slotsError = slotsError;
    });
    final error =
        supportError ?? allowanceError ?? programBudgetError ?? slotsError;
    if (error != null) return;

    setState(() => _saving = true);
    try {
      await _catalogService.setProgramBudget(
        program: widget.program.name,
        budget: programBudget,
      );
      await _catalogService.setDetails(
        id: widget.program.id,
        description:
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        allowanceAmount: allowanceAmount,
        payoutFrequency: _payoutFrequency,
        supportFromYear: _supportFromYear,
        supportToYear: _supportToYear,
        slots: slots,
      );
      if (!mounted) return;
      showAppSnackBar(context, 'Program details saved.');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          error is ScholarshipCatalogException
              ? error.message
              : 'Could not save program details. Please try again.',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          leadingWidth: 70,
          leading: Padding(
            padding: const EdgeInsets.only(left: 26),
            child: IconButton(
              onPressed: _saving ? null : () => Navigator.maybePop(context),
              style: IconButton.styleFrom(
                fixedSize: const Size(42, 42),
                padding: EdgeInsets.zero,
                backgroundColor: colors.surface,
                foregroundColor: colors.textPrimary,
                shape: const CircleBorder(),
                side: BorderSide(color: colors.borderSoft),
              ),
              icon: const Icon(AppIcons.back, size: 20),
            ),
          ),
          title: Text(
            'Program details',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
          backgroundColor: colors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  _sectionCard(
                    context,
                    label: 'ABOUT',
                    icon: AppIcons.award,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.program.name,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel('Description', colors.textLabel),
                        TextField(
                          key: const ValueKey('program-description'),
                          controller: _description,
                          enabled: !_saving,
                          maxLength: 600,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          maxLines: 4,
                          minLines: 4,
                          scrollPadding: const EdgeInsets.only(bottom: 120),
                          onTapOutside: (_) => FocusScope.of(context).unfocus(),
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: _fieldDecoration(
                            context,
                            hintText: 'Describe who this scholarship is for',
                            alignLabelWithHint: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            counterStyle: TextStyle(
                              color: colors.hintContrast,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    context,
                    label: 'ALLOWANCE',
                    icon: AppIcons.wallet,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _fieldLabel('Allowance amount (PHP)', colors.textLabel),
                        TextField(
                          key: const ValueKey('program-allowance'),
                          controller: _allowance,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          scrollPadding: const EdgeInsets.only(bottom: 120),
                          onTapOutside: (_) => FocusScope.of(context).unfocus(),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _fieldDecoration(
                            context,
                            hintText: 'Not set yet',
                            errorText: _allowanceError,
                            prefixIcon: Padding(
                              padding:
                                  const EdgeInsets.only(left: 14, right: 8),
                              child: Center(
                                widthFactor: 1,
                                child: Text(
                                  'PHP',
                                  style: TextStyle(
                                    color: colors.textBody,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 54,
                              minHeight: 52,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel('Program budget (PHP)', colors.textLabel),
                        TextField(
                          key: const ValueKey('program-budget'),
                          controller: _programBudget,
                          enabled: !_saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          scrollPadding: const EdgeInsets.only(bottom: 120),
                          onTapOutside: (_) => FocusScope.of(context).unfocus(),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _fieldDecoration(
                            context,
                            hintText: 'No budget set',
                            errorText: _programBudgetError,
                            prefixIcon: Padding(
                              padding:
                                  const EdgeInsets.only(left: 14, right: 8),
                              child: Center(
                                widthFactor: 1,
                                child: Text(
                                  'PHP',
                                  style: TextStyle(
                                    color: colors.textBody,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 54,
                              minHeight: 52,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _budgetSummary(context),
                        const SizedBox(height: 16),
                        _fieldLabel('Paid every', colors.textLabel),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                key: const ValueKey('program-frequency'),
                                height: 52,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: colors.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _frequencyOption(
                                        context,
                                        label: 'Month',
                                        value: 'monthly',
                                      ),
                                    ),
                                    Expanded(
                                      child: _frequencyOption(
                                        context,
                                        label: 'Semester',
                                        value: 'semester',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            TextButton(
                              key: const ValueKey('program-frequency-clear'),
                              onPressed: _saving
                                  ? null
                                  : () =>
                                      setState(() => _payoutFrequency = null),
                              style: TextButton.styleFrom(
                                foregroundColor: colors.brand,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(0, 40),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    context,
                    label: 'SUPPORT PERIOD',
                    icon: AppIcons.calendar,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _fieldLabel('From year', colors.textLabel),
                                  _yearDropdown(
                                    key: const ValueKey(
                                      'program-support-from',
                                    ),
                                    value: _supportFromYear,
                                    onChanged: _saving
                                        ? null
                                        : (value) => setState(() {
                                              _supportFromYear = value;
                                              _supportError = null;
                                            }),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: SizedBox(
                                height: 76,
                                child: Center(
                                  child: Text(
                                    'to',
                                    style: TextStyle(
                                      color: colors.textBody,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _fieldLabel('To year', colors.textLabel),
                                  _yearDropdown(
                                    key: const ValueKey('program-support-to'),
                                    value: _supportToYear,
                                    errorText: _supportError,
                                    onChanged: _saving
                                        ? null
                                        : (value) => setState(() {
                                              _supportToYear = value;
                                              _supportError = null;
                                            }),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _supportSummary,
                          style: TextStyle(
                            color: colors.textBody,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    context,
                    label: 'SLOTS',
                    icon: AppIcons.users,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _fieldLabel('Slots', colors.textLabel),
                        TextField(
                          key: const ValueKey('program-slots'),
                          controller: _slots,
                          keyboardType: TextInputType.number,
                          scrollPadding: const EdgeInsets.only(bottom: 120),
                          onTapOutside: (_) => FocusScope.of(context).unfocus(),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _fieldDecoration(
                            context,
                            hintText: 'No limit',
                            errorText: _slotsError,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: colors.brandTint,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              widget.program.slots == null
                                  ? '${widget.program.slotsTaken} slots used'
                                  : '${widget.program.slotsTaken} of '
                                      '${widget.program.slots} slots used',
                              style: TextStyle(
                                color: colors.brandTintText,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: PrimaryButton(
                  label: 'Save',
                  onPressed: _saving ? null : _save,
                  loading: _saving,
                  minHeight: 56,
                  borderRadius: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );

  Widget _budgetSummary(BuildContext context) {
    final colors = context.colors;
    Widget value(String label, String content) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.textBody,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          value('Used', 'PHP ${fmtPhp(_budgetUsed)}'),
          const SizedBox(width: 12),
          value(
            'Remaining',
            _budgetRemaining == null
                ? 'No budget set'
                : 'PHP ${fmtPhp(_budgetRemaining!)}',
          ),
        ],
      ),
    );
  }

  String get _supportSummary {
    final fromYear = _supportFromYear;
    final toYear = _supportToYear;
    if (fromYear == null || toYear == null) return 'Not set yet';
    return '${ordinalNumber(fromYear)} year to ${ordinalNumber(toYear)} year';
  }

  Widget _sectionCard(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.brandTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: colors.brand, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SectionLabel(
                  label,
                  labelColor: colors.hintContrast,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _frequencyOption(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final colors = context.colors;
    final selected = _payoutFrequency == value;
    return Material(
      color: selected ? colors.brand : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('program-frequency-$value'),
        borderRadius: BorderRadius.circular(12),
        onTap: _saving ? null : () => setState(() => _payoutFrequency = value),
        child: SizedBox(
          height: double.infinity,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? colors.onHeader : colors.textBody,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String hintText,
    String? errorText,
    bool alignLabelWithHint = false,
    EdgeInsetsGeometry? contentPadding,
    TextStyle? counterStyle,
    Widget? prefixIcon,
    BoxConstraints? prefixIconConstraints,
  }) {
    final colors = context.colors;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.border),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.brand, width: 2),
    );
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: colors.hintContrast),
      errorText: errorText,
      alignLabelWithHint: alignLabelWithHint,
      prefixIcon: prefixIcon,
      prefixIconConstraints: prefixIconConstraints,
      isDense: true,
      filled: true,
      fillColor: colors.surface,
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      counterStyle: counterStyle,
      border: border,
      enabledBorder: border,
      focusedBorder: focusedBorder,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.danger),
      ),
      focusedErrorBorder: focusedBorder,
    );
  }

  Widget _yearDropdown({
    required Key key,
    required int? value,
    required ValueChanged<int?>? onChanged,
    String? errorText,
  }) {
    return DropdownButtonFormField<int>(
      key: key,
      initialValue: value ?? 0,
      isExpanded: true,
      decoration: _fieldDecoration(
        context,
        hintText: 'Not set yet',
        errorText: errorText,
      ),
      items: [
        const DropdownMenuItem(
          value: 0,
          child: Text('Not set yet'),
        ),
        for (var year = 1; year <= 6; year++)
          DropdownMenuItem(
            value: year,
            child: Text('${ordinalNumber(year)} year'),
          ),
      ],
      onChanged: onChanged == null
          ? null
          : (selectedYear) => onChanged(
              selectedYear == null || selectedYear == 0 ? null : selectedYear),
    );
  }
}
