import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/scholarship_catalog_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/widgets.dart';
import 'scholarship_details_screen.dart';
import 'selfie_flow_screen.dart';

String normalizeNamePart(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

String composeFullName(String firstName, String? middleName, String lastName) {
  final first = normalizeNamePart(firstName);
  final middle = normalizeNamePart(middleName ?? '');
  final last = normalizeNamePart(lastName);
  return [first, middle, last].where((part) => part.isNotEmpty).join(' ');
}

bool isValidBirthdate(DateTime? birthdate, {DateTime? today}) {
  if (birthdate == null) return false;
  final date = DateUtils.dateOnly(birthdate);
  final latest = DateUtils.dateOnly(today ?? DateTime.now());
  return !date.isAfter(latest) && !date.isBefore(DateTime(1900, 1, 1));
}

class SignupScreen extends StatefulWidget {
  final ScholarshipCatalogService? catalogService;

  const SignupScreen({
    super.key,
    this.catalogService,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const _yearLevels = [
    '1st Year College',
    '2nd Year College',
    '3rd Year College',
    '4th Year College',
    '5th Year College',
  ];

  static const _academicFieldOrder = [
    'lastName',
    'firstName',
    'middleName',
    'birthdate',
    'studentNo',
    'university',
    'program',
    'yearLevel',
    'scholarshipName',
  ];
  static const _securityFieldOrder = [
    'email',
    'confirmEmail',
    'password',
    'confirm',
    'terms',
  ];

  final _lastName = TextEditingController();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _birthdateController = TextEditingController();
  final _studentNo = TextEditingController();
  final _university = TextEditingController();
  final _program = TextEditingController();
  final _scholarshipName = TextEditingController();
  final _email = TextEditingController();
  final _confirmEmail = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _scrollController = ScrollController();
  final _fieldKeys = <String, GlobalKey>{
    for (final key in [
      ..._academicFieldOrder,
      ..._securityFieldOrder,
    ])
      key: GlobalKey(),
  };

  String? _yearLevel;
  DateTime? _birthdate;
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _agreed = false;
  bool _busy = false;
  bool _catalogLoading = false;
  bool _catalogAttempted = false;
  bool _scholarshipTextFallback = false;
  bool _confirmEmailEdited = false;
  int _step = 0;
  List<ScholarshipCatalogItem> _scholarshipPrograms = [];
  final Map<String, String> _fieldErrors = {};
  late final ScholarshipCatalogService _catalogService =
      widget.catalogService ?? ScholarshipCatalogService();

  @override
  void dispose() {
    _lastName.dispose();
    _firstName.dispose();
    _middleName.dispose();
    _birthdateController.dispose();
    _studentNo.dispose();
    _university.dispose();
    _program.dispose();
    _scholarshipName.dispose();
    _email.dispose();
    _confirmEmail.dispose();
    _password.dispose();
    _confirm.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? _validateAcademicDetails() {
    final errors = _academicErrors();
    if (errors.isNotEmpty) return 'Fill in all fields.';
    return null;
  }

  Map<String, String> _academicErrors() {
    final errors = <String, String>{};
    final lastName = normalizeNamePart(_lastName.text);
    final firstName = normalizeNamePart(_firstName.text);
    final middleName = normalizeNamePart(_middleName.text);
    if (lastName.isEmpty || lastName.length > 60) {
      errors['lastName'] = 'Enter a last name (up to 60 characters).';
    }
    if (firstName.isEmpty || firstName.length > 60) {
      errors['firstName'] = 'Enter a first name (up to 60 characters).';
    }
    if (middleName.length > 60) {
      errors['middleName'] = 'Use at most 60 characters.';
    }
    if (!isValidBirthdate(_birthdate)) {
      errors['birthdate'] = 'Enter a valid birthdate.';
    }
    if (_studentNo.text.trim().isEmpty) {
      errors['studentNo'] = 'This field is required.';
    }
    if (_university.text.trim().isEmpty) {
      errors['university'] = 'This field is required.';
    }
    if (_program.text.trim().isEmpty) {
      errors['program'] = 'This field is required.';
    }
    if (_yearLevel == null) errors['yearLevel'] = 'Select your year level.';
    if (_scholarshipName.text.trim().isEmpty) {
      errors['scholarshipName'] = 'This field is required.';
    }
    return errors;
  }

  Future<void> _pickBirthdate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initialDate =
        _birthdate ?? DateTime(today.year - 18, today.month, today.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900, 1, 1),
      lastDate: today,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _birthdate = DateUtils.dateOnly(selected);
      _birthdateController.text = DateFormat('MMM d, yyyy').format(_birthdate!);
      _fieldErrors.remove('birthdate');
    });
  }

  String? _validateAccountSecurity() {
    if (_email.text.trim().isEmpty ||
        _confirmEmail.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _confirm.text.isEmpty) {
      return 'Fill in all fields.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
      return 'Please enter a valid email address.';
    }
    if (_password.text.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (_password.text != _confirm.text) {
      return 'Passwords do not match.';
    }
    if (_emailConfirmationError() != null) {
      return 'Emails do not match.';
    }
    if (!_agreed) {
      return 'Please accept the Terms of Service and Privacy Policy.';
    }
    return null;
  }

  Map<String, String> _securityErrors() {
    final errors = <String, String>{};
    if (_email.text.trim().isEmpty) {
      errors['email'] = 'This field is required.';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(_email.text.trim())) {
      errors['email'] = 'Please enter a valid email address.';
    }
    final confirmEmailError = _emailConfirmationError();
    if (confirmEmailError != null) {
      errors['confirmEmail'] = confirmEmailError;
    }
    if (_password.text.isEmpty) {
      errors['password'] = 'This field is required.';
    } else if (_password.text.length < 6) {
      errors['password'] = 'Password must be at least 6 characters.';
    }
    if (_confirm.text.isEmpty) {
      errors['confirm'] = 'This field is required.';
    } else if (_password.text != _confirm.text) {
      errors['confirm'] = 'Passwords do not match.';
    }
    if (!_agreed) {
      errors['terms'] =
          'Please accept the Terms of Service and Privacy Policy.';
    }
    return errors;
  }

  String? _emailConfirmationError() {
    if (_confirmEmail.text.trim().isEmpty) return 'This field is required.';
    if (_email.text.trim().toLowerCase() !=
        _confirmEmail.text.trim().toLowerCase()) {
      return 'Emails do not match.';
    }
    return null;
  }

  void _onConfirmEmailFocusChanged(bool hasFocus) {
    if (hasFocus || !_confirmEmailEdited) return;
    final error = _emailConfirmationError();
    if (_fieldErrors['confirmEmail'] == error) return;
    setState(() {
      if (error == null) {
        _fieldErrors.remove('confirmEmail');
      } else {
        _fieldErrors['confirmEmail'] = error;
      }
    });
  }

  void _continueToSecurity() {
    final error = _validateAcademicDetails();
    if (error != null) {
      setState(() {
        _fieldErrors
          ..clear()
          ..addAll(_academicErrors());
      });
      _scrollToFirstError(_academicFieldOrder);
      showMsg(context, error, error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _fieldErrors.clear();
      _step = 1;
    });
    _scrollToTop();
  }

  void _returnToAcademicDetails() {
    FocusScope.of(context).unfocus();
    setState(() => _step = 0);
    _scrollToTop();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _scrollToFirstError(List<String> order) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final field in order) {
        if (_fieldErrors.containsKey(field)) {
          final fieldContext = _fieldKeys[field]?.currentContext;
          if (fieldContext != null) {
            Scrollable.ensureVisible(
              fieldContext,
              alignment: 0.12,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOut,
            );
          }
          return;
        }
      }
    });
  }

  void _onFieldChanged(String key) {
    setState(() {
      _fieldErrors.remove(key);
      if (key == 'confirmEmail') {
        _confirmEmailEdited = true;
      } else if (key == 'email' && _confirmEmailEdited) {
        final emailError = _emailConfirmationError();
        if (emailError != null) {
          _fieldErrors['confirmEmail'] = emailError;
        } else {
          _fieldErrors.remove('confirmEmail');
        }
      }
      if (key == 'password') _fieldErrors.remove('confirm');
    });
  }

  void _clearFieldError(String key) {
    if (_fieldErrors.containsKey(key)) {
      setState(() => _fieldErrors.remove(key));
    }
  }

  Future<void> _showPolicySheet(String title) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AppBottomSheet(
        title: title,
        child: Text(
          '$title text will be provided.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: context.colors.textBody,
          ),
        ),
      ),
    );
  }

  Future<void> _signup() async {
    final error = _validateAccountSecurity();
    if (error != null) {
      setState(() {
        _fieldErrors
          ..clear()
          ..addAll(_securityErrors());
      });
      _scrollToFirstError(_securityFieldOrder);
      showMsg(context, error, error: true);
      return;
    }
    _clearAllFieldErrors();
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      await state.auth.signUp(
        fullName: composeFullName(
          _firstName.text,
          _middleName.text,
          _lastName.text,
        ),
        email: _email.text,
        password: _password.text,
        lastName: normalizeNamePart(_lastName.text),
        firstName: normalizeNamePart(_firstName.text),
        middleName: normalizeNamePart(_middleName.text).isEmpty
            ? null
            : normalizeNamePart(_middleName.text),
        birthdate: _birthdate!,
        studentNumber: _studentNo.text,
        university: _university.text,
        program: _program.text,
        yearLevel: _yearLevel!,
        declaredScholar: true,
        scholarshipName: _scholarshipName.text,
      );
      if (mounted) {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => SelfieIntroScreen(
              onSubmitted: state.refreshProfile,
            ),
          ),
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final friendlyMessage = context.read<AppState>().auth.friendlyError(e);
        final message = friendlyMessage.contains('INVALID_BIRTHDATE') ||
                friendlyMessage.contains('INVALID_NAME_PART')
            ? 'Please check your birthdate and name.'
            : friendlyMessage;
        final field = _signupErrorField(message);
        if (field != null) {
          setState(() {
            _step = 0;
            _fieldErrors[field] = message;
          });
          _scrollToFirstError(_academicFieldOrder);
        }
        showMsg(context, message, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _signupErrorField(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('student') &&
        (normalized.contains('duplicate') ||
            normalized.contains('already') ||
            normalized.contains('unique') ||
            normalized.contains('exists') ||
            normalized.contains('taken'))) {
      return 'studentNo';
    }
    if (normalized.contains('scholarship')) return 'scholarshipName';
    if (normalized.contains('year level')) return 'yearLevel';
    if (normalized.contains('university')) return 'university';
    if (normalized.contains('program')) return 'program';
    if (normalized.contains('last name')) return 'lastName';
    if (normalized.contains('first name')) return 'firstName';
    if (normalized.contains('middle name')) return 'middleName';
    if (normalized.contains('birthdate')) return 'birthdate';
    if (normalized.contains('full name') || normalized.contains('full_name')) {
      return 'firstName';
    }
    return null;
  }

  void _clearAllFieldErrors() {
    if (_fieldErrors.isNotEmpty) {
      setState(_fieldErrors.clear);
    }
  }

  int get _passwordStrength {
    final password = _password.text;
    if (password.isEmpty || password.length < 8) {
      return password.isEmpty ? 0 : 1;
    }
    if (!RegExp(r'\d').hasMatch(password)) return 2;
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) return 3;
    return 4;
  }

  String get _passwordStrengthLabel => switch (_passwordStrength) {
        0 => 'Add a password to see its strength',
        1 => 'Weak - add more characters',
        2 => 'Okay - add a number',
        3 => 'Good password · add a symbol to make it strong',
        _ => 'Strong password',
      };

  Color _passwordStrengthColor(BuildContext context) =>
      switch (_passwordStrength) {
        0 => context.colors.textBody,
        1 => context.colors.dangerText,
        2 => context.colors.warningText,
        _ => context.colors.successText,
      };

  TextStyle _label(BuildContext context) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.colors.textLabel,
      );

  InputDecoration _decoration(
    BuildContext context,
    String hint,
    IconData icon, {
    Widget? suffix,
    String? error,
  }) {
    final colors = context.colors;
    return InputDecoration(
      filled: true,
      fillColor: colors.background,
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 14, color: colors.hint),
      prefixIcon: Icon(icon, size: 20, color: colors.textBody),
      prefixIconConstraints: const BoxConstraints(minWidth: 48),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      errorText: error,
      errorStyle: GoogleFonts.inter(fontSize: 12, color: colors.dangerText),
      border: _border(colors.border),
      enabledBorder: _border(colors.border),
      focusedBorder: _border(colors.brand, width: 2),
      errorBorder: _border(colors.dangerBorder),
      focusedErrorBorder: _border(colors.dangerBorder, width: 2),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  Widget _field(
    BuildContext context,
    String label,
    Widget input, {
    String? fieldKey,
    bool bottomPadding = true,
  }) =>
      Padding(
        key: fieldKey == null ? null : _fieldKeys[fieldKey],
        padding: EdgeInsets.only(bottom: bottomPadding ? 16 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _label(context)),
            const SizedBox(height: 6),
            input,
          ],
        ),
      );

  Widget _text(
    BuildContext context,
    String label,
    String key,
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType? type,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputAction action = TextInputAction.next,
    bool obscure = false,
    Widget? suffix,
    Iterable<String>? autofillHints,
    bool bottomPadding = true,
  }) =>
      _field(
        context,
        label,
        AppTextField(
          controller: controller,
          keyboardType: type,
          textInputAction: action,
          textCapitalization: capitalization,
          obscureText: obscure,
          autofillHints: autofillHints,
          onChanged: (_) => _onFieldChanged(key),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: context.colors.textPrimary,
          ),
          decoration: _decoration(
            context,
            hint,
            icon,
            error: _fieldErrors[key],
            suffix: suffix,
          ),
        ),
        fieldKey: key,
        bottomPadding: bottomPadding,
      );

  Widget _academicCard(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _text(
            context,
            'Last name',
            'lastName',
            _lastName,
            'Dela Cruz',
            AppIcons.user,
            capitalization: TextCapitalization.words,
          ),
          _text(
            context,
            'First name',
            'firstName',
            _firstName,
            'Juan',
            AppIcons.user,
            capitalization: TextCapitalization.words,
          ),
          _text(
            context,
            'Middle name (optional)',
            'middleName',
            _middleName,
            'Santos',
            AppIcons.user,
            capitalization: TextCapitalization.words,
          ),
          _field(
            context,
            'Birthdate',
            AppTextField(
              controller: _birthdateController,
              readOnly: true,
              onTap: _pickBirthdate,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: context.colors.textPrimary,
              ),
              decoration: _decoration(
                context,
                'Select birthdate',
                AppIcons.calendar,
                error: _fieldErrors['birthdate'],
              ),
            ),
            fieldKey: 'birthdate',
          ),
          _text(
            context,
            'Student Number',
            'studentNo',
            _studentNo,
            '20243771',
            AppIcons.idCard,
            type: TextInputType.number,
          ),
          _text(
            context,
            'University / College',
            'university',
            _university,
            'Urdaneta City University',
            AppIcons.school,
            capitalization: TextCapitalization.words,
          ),
          _text(
            context,
            'Program / Course',
            'program',
            _program,
            'B.S. Information Technology',
            AppIcons.book,
            capitalization: TextCapitalization.words,
          ),
          _field(
            context,
            'Year Level',
            DropdownButtonFormField<String>(
              initialValue: _yearLevel,
              isExpanded: true,
              icon: Icon(AppIcons.chevronDown, color: colors.textBody),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colors.textPrimary,
              ),
              decoration: _decoration(
                context,
                'Select year level',
                AppIcons.award,
                error: _fieldErrors['yearLevel'],
              ),
              items: _yearLevels
                  .map((year) => DropdownMenuItem(
                        value: year,
                        child: Text(year, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _yearLevel = value);
                _clearFieldError('yearLevel');
              },
            ),
            fieldKey: 'yearLevel',
          ),
          const SizedBox(height: 12),
          _scholarshipField(context),
        ],
      ),
    );
  }

  Widget _scholarshipField(BuildContext context) {
    if (_scholarshipTextFallback) {
      return _text(
        context,
        'Scholarship',
        'scholarshipName',
        _scholarshipName,
        'e.g. CHED Merit Scholarship',
        AppIcons.award,
        capitalization: TextCapitalization.words,
      );
    }

    return _field(
      context,
      'Scholarship',
      InkWell(
        key: const ValueKey('scholarship-picker-field'),
        onTap: _catalogLoading ? null : _openScholarshipPicker,
        borderRadius: BorderRadius.circular(16),
        child: InputDecorator(
          decoration: _decoration(
            context,
            '',
            AppIcons.award,
            error: _fieldErrors['scholarshipName'],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _catalogLoading
                      ? 'Loading scholarships...'
                      : _scholarshipName.text.isEmpty
                          ? 'Select your scholarship'
                          : _scholarshipName.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _scholarshipName.text.isEmpty
                        ? context.colors.hint
                        : context.colors.textPrimary,
                  ),
                ),
              ),
              if (_catalogLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.brand,
                  ),
                )
              else
                Icon(
                  AppIcons.chevronDown,
                  size: 18,
                  color: context.colors.textBody,
                ),
            ],
          ),
        ),
      ),
      fieldKey: 'scholarshipName',
    );
  }

  Future<void> _openScholarshipPicker() async {
    if (_catalogLoading) return;
    if (!_catalogAttempted) {
      setState(() => _catalogLoading = true);
      try {
        final programs = await _catalogService.list(includeInactive: false);
        if (!mounted) return;
        setState(() {
          _scholarshipPrograms = programs;
          _catalogAttempted = true;
          _scholarshipTextFallback = programs.isEmpty;
        });
      } catch (_) {
        if (!mounted) return;
        // Manual entry remains available if the catalog cannot be loaded.
        setState(() {
          _catalogAttempted = true;
          _scholarshipTextFallback = true;
        });
      } finally {
        if (mounted) setState(() => _catalogLoading = false);
      }
    }

    if (!mounted || _scholarshipTextFallback) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScholarshipPickerSheet(
        programs: _scholarshipPrograms,
        selectedName: _scholarshipName.text,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _scholarshipName.text = selected;
      _fieldErrors.remove('scholarshipName');
    });
  }

  Widget _securityCard(BuildContext context) {
    final strength = _passwordStrength;
    final strengthColor = _passwordStrengthColor(context);
    final confirmError = _fieldErrors['confirm'] ??
        (_confirm.text.isNotEmpty && _password.text != _confirm.text
            ? 'Passwords do not match.'
            : null);
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _text(
            context,
            'School Email Address',
            'email',
            _email,
            'juandelacruz12@school.edu',
            AppIcons.mail,
            type: TextInputType.emailAddress,
          ),
          Focus(
            onFocusChange: _onConfirmEmailFocusChanged,
            child: _text(
              context,
              'Confirm email',
              'confirmEmail',
              _confirmEmail,
              'Re-enter your school email',
              AppIcons.mail,
              type: TextInputType.emailAddress,
              autofillHints: const [],
            ),
          ),
          _text(
            context,
            'Password',
            'password',
            _password,
            'Enter a password',
            AppIcons.lock,
            obscure: _obscurePw,
            suffix: IconButton(
              tooltip: _obscurePw ? 'Show password' : 'Hide password',
              icon: Icon(
                _obscurePw ? AppIcons.eye : AppIcons.eyeOff,
                size: 20,
                color: context.colors.textBody,
              ),
              onPressed: () => setState(() => _obscurePw = !_obscurePw),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    4,
                    (index) => Expanded(
                      child: Container(
                        height: 6,
                        margin: EdgeInsets.only(right: index == 3 ? 0 : 6),
                        decoration: BoxDecoration(
                          color: index < strength
                              ? strengthColor
                              : context.colors.borderSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _passwordStrengthLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: strengthColor,
                  ),
                ),
              ],
            ),
          ),
          _field(
            context,
            'Confirm Password',
            AppTextField(
              controller: _confirm,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onChanged: (_) => _onFieldChanged('confirm'),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: context.colors.textPrimary,
              ),
              decoration: _decoration(
                context,
                'Re-enter password',
                AppIcons.lock,
                error: confirmError,
                suffix: IconButton(
                  tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscureConfirm ? AppIcons.eye : AppIcons.eyeOff,
                    size: 20,
                    color: context.colors.textBody,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirm = !_obscureConfirm,
                  ),
                ),
              ),
            ),
            fieldKey: 'confirm',
            bottomPadding: false,
          ),
        ],
      ),
    );
  }

  Widget _terms(BuildContext context) {
    final colors = context.colors;
    return Column(
      key: _fieldKeys['terms'],
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(
                value: _agreed,
                activeColor: colors.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
                side: BorderSide(color: colors.brand, width: 1.5),
                onChanged: (value) {
                  setState(() => _agreed = value ?? false);
                  _clearFieldError('terms');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Wrap(
                  children: [
                    Text(
                      'I agree to the Scholar Wallet ',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.5,
                        color: colors.textBody,
                      ),
                    ),
                    InkWell(
                      onTap: () => _showPolicySheet('Terms of Service'),
                      child: Text(
                        'Terms of Service',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                          color: colors.brand,
                        ),
                      ),
                    ),
                    Text(
                      ' and ',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.5,
                        color: colors.textBody,
                      ),
                    ),
                    InkWell(
                      onTap: () => _showPolicySheet('Privacy Policy'),
                      child: Text(
                        'Privacy Policy',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                          color: colors.brand,
                        ),
                      ),
                    ),
                    Text(
                      ' for financial disbursement.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.5,
                        color: colors.textBody,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_fieldErrors['terms'] != null)
          Padding(
            padding: const EdgeInsets.only(left: 40, top: 4),
            child: Text(
              _fieldErrors['terms']!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: colors.dangerText,
              ),
            ),
          ),
      ],
    );
  }

  Widget _progress(BuildContext context) {
    final colors = context.colors;
    final stepName = _step == 0 ? 'Academic details' : 'Account security';
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Step ${_step + 1} of 3',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textLabel,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                stepName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.brand,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _progressBar(colors.brand),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _progressBar(
                _step == 1 ? colors.brand : colors.border,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _progressBar(colors.border)),
          ],
        ),
      ],
    );
  }

  Widget _progressBar(Color color) => Container(
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
      );

  Widget _screenHeading(BuildContext context) {
    final colors = context.colors;
    final title = _step == 0 ? 'Create Student Account' : 'Secure your account';
    final subtitle = _step == 0
        ? 'Register with your academic details to start receiving and tracking your scholarships.'
        : 'Use your school email and choose a strong password to protect your allowance.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.15,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
            color: colors.textBody,
          ),
        ),
      ],
    );
  }

  Widget _bottomBar(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: _step == 0 ? 'Continue' : 'Create Account',
            onPressed: _step == 0 ? _continueToSecurity : _signup,
            loading: _step == 1 && _busy,
            minHeight: 56,
            borderRadius: 18,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: colors.textBody,
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Text(
                  'Sign In',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.brand,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _step == 1) _returnToAcademicDetails();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          surfaceTintColor: Colors.transparent,
          leadingWidth: 70,
          leading: Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Material(
              color: colors.surface,
              shape: CircleBorder(
                side: BorderSide(color: colors.borderSoft),
              ),
              child: IconButton(
                onPressed: () {
                  if (_step == 1) {
                    _returnToAcademicDetails();
                  } else {
                    Navigator.pop(context);
                  }
                },
                tooltip: 'Back',
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                icon: Icon(AppIcons.back, color: colors.textPrimary),
              ),
            ),
          ),
          title: const Text('Sign up'),
          actions: const [SizedBox(width: 70)],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _progress(context),
                      const SizedBox(height: 28),
                      _screenHeading(context),
                      const SizedBox(height: 20),
                      if (_step == 0)
                        _academicCard(context)
                      else ...[
                        _securityCard(context),
                        const SizedBox(height: 18),
                        _terms(context),
                      ],
                    ],
                  ),
                ),
              ),
              _bottomBar(context),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScholarshipPickerSheet extends StatefulWidget {
  final List<ScholarshipCatalogItem> programs;
  final String selectedName;

  const _ScholarshipPickerSheet({
    required this.programs,
    required this.selectedName,
  });

  @override
  State<_ScholarshipPickerSheet> createState() =>
      _ScholarshipPickerSheetState();
}

class _ScholarshipPickerSheetState extends State<_ScholarshipPickerSheet> {
  String? _selectedName;

  @override
  void initState() {
    super.initState();
    if (widget.programs.any((program) => program.name == widget.selectedName)) {
      _selectedName = widget.selectedName;
    }
  }

  Widget _option(ScholarshipCatalogItem program) {
    final selected = _selectedName == program.name;
    return Material(
      color: selected ? context.colors.brandTint : context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final selectedName = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (_) => ScholarshipDetailsScreen(program: program),
            ),
          );
          if (selectedName != null && mounted) {
            setState(() => _selectedName = selectedName);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  selected ? context.colors.brand : context.colors.borderSoft,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  program.name,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(
                  AppIcons.check,
                  color: context.colors.brand,
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Choose your scholarship',
      showDragHandle: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pick the one you already belong to.',
            style: TextStyle(
              color: context.colors.textBody,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < widget.programs.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _option(widget.programs[index]),
          ],
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Done',
            onPressed: () => Navigator.pop(context, _selectedName),
            minHeight: 52,
            borderRadius: 18,
          ),
        ],
      ),
    );
  }
}
