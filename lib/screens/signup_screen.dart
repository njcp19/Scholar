import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

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
    'name',
    'studentNo',
    'university',
    'program',
    'yearLevel',
    'scholarshipName',
  ];
  static const _securityFieldOrder = [
    'email',
    'password',
    'confirm',
    'terms',
  ];

  final _name = TextEditingController();
  final _studentNo = TextEditingController();
  final _university = TextEditingController();
  final _program = TextEditingController();
  final _scholarshipName = TextEditingController();
  final _scholarshipReference = TextEditingController();
  final _email = TextEditingController();
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
  bool _declaredScholar = true;
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _agreed = false;
  bool _busy = false;
  int _step = 0;
  final Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _name.dispose();
    _studentNo.dispose();
    _university.dispose();
    _program.dispose();
    _scholarshipName.dispose();
    _scholarshipReference.dispose();
    _email.dispose();
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
    if (_name.text.trim().isEmpty) errors['name'] = 'This field is required.';
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
    if (_declaredScholar && _scholarshipName.text.trim().isEmpty) {
      errors['scholarshipName'] = 'This field is required.';
    }
    return errors;
  }

  String? _validateAccountSecurity() {
    if (_email.text.trim().isEmpty ||
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
          style: GoogleFonts.poppins(
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
      final messenger = ScaffoldMessenger.of(context);
      final successColor = context.colors.success;
      await state.auth.signUp(
        fullName: _name.text,
        email: _email.text,
        password: _password.text,
        studentNumber: _studentNo.text,
        university: _university.text,
        program: _program.text,
        yearLevel: _yearLevel!,
        declaredScholar: _declaredScholar,
        scholarshipName: _scholarshipName.text,
        scholarshipReference: _scholarshipReference.text,
      );
      // AuthGate opens the verification status screen for this signed-in account.
      if (mounted) {
        Navigator.pop(context);
      }
      messenger.showSnackBar(SnackBar(
        content: const Text('Registration submitted for admin verification.'),
        backgroundColor: successColor,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) {
        final message = context.read<AppState>().auth.friendlyError(e);
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
    if (normalized.contains('full name') || normalized.contains('full_name')) {
      return 'name';
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

  TextStyle _label(BuildContext context) => GoogleFonts.poppins(
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
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: colors.textBody),
      prefixIcon: Icon(icon, size: 20, color: colors.textBody),
      prefixIconConstraints: const BoxConstraints(minWidth: 48),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      errorText: error,
      errorStyle: GoogleFonts.poppins(fontSize: 12, color: colors.dangerText),
      border: _border(colors.borderSoft),
      enabledBorder: _border(colors.borderSoft),
      focusedBorder: _border(colors.brand, width: 2),
      errorBorder: _border(colors.danger),
      focusedErrorBorder: _border(colors.brand, width: 2),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
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
          onChanged: (_) => _onFieldChanged(key),
          style: GoogleFonts.poppins(
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
      padding: const EdgeInsets.all(24),
      radius: 28,
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _text(
            context,
            'Full Name',
            'name',
            _name,
            'Juan Dela Cruz',
            AppIcons.user,
            capitalization: TextCapitalization.words,
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
              style: GoogleFonts.poppins(
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
          const SizedBox(height: 2),
          Text(
            'EXISTING SCHOLARSHIP',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colors.textLabel,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('I am already a scholar', style: _label(context)),
                    const SizedBox(height: 2),
                    Text(
                      'Scholar Wallet is only for existing scholarship beneficiaries.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.4,
                        color: colors.textBody,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _declaredScholar,
                onChanged: (value) {
                  setState(() {
                    _declaredScholar = value;
                    if (!value) _fieldErrors.remove('scholarshipName');
                  });
                },
              ),
            ],
          ),
          if (!_declaredScholar) ...[
            const SizedBox(height: 8),
            const InfoBanner(
              icon: AppIcons.info,
              message:
                  'Scholar Wallet verifies existing scholars only. You can still register, but you cannot receive allowance until you are verified.',
              maxLines: 10,
            ),
          ],
          if (_declaredScholar) ...[
            const SizedBox(height: 12),
            _text(
              context,
              'Scholarship name',
              'scholarshipName',
              _scholarshipName,
              'e.g. CHED Merit Scholarship',
              AppIcons.award,
              capitalization: TextCapitalization.words,
            ),
            _text(
              context,
              'Award reference or ID',
              'scholarshipReference',
              _scholarshipReference,
              'Optional',
              AppIcons.idCard,
              action: TextInputAction.done,
              bottomPadding: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _securityCard(BuildContext context) {
    final strength = _passwordStrength;
    final strengthColor = _passwordStrengthColor(context);
    final confirmError = _fieldErrors['confirm'] ??
        (_confirm.text.isNotEmpty && _password.text != _confirm.text
            ? 'Passwords do not match.'
            : null);
    return AppCard(
      padding: const EdgeInsets.all(24),
      radius: 28,
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
                  style: GoogleFonts.poppins(
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
              style: GoogleFonts.poppins(
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
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.5,
                        color: colors.textBody,
                      ),
                    ),
                    InkWell(
                      onTap: () => _showPolicySheet('Terms of Service'),
                      child: Text(
                        'Terms of Service',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                          color: colors.brand,
                        ),
                      ),
                    ),
                    Text(
                      ' and ',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.5,
                        color: colors.textBody,
                      ),
                    ),
                    InkWell(
                      onTap: () => _showPolicySheet('Privacy Policy'),
                      child: Text(
                        'Privacy Policy',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                          color: colors.brand,
                        ),
                      ),
                    ),
                    Text(
                      ' for financial disbursement.',
                      style: GoogleFonts.poppins(
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
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: colors.dangerText,
              ),
            ),
          ),
      ],
    );
  }

  Widget _topBar(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Material(
          color: colors.surface,
          shape: CircleBorder(
            side: BorderSide(color: colors.borderSoft),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              if (_step == 1) {
                _returnToAcademicDetails();
              } else {
                Navigator.pop(context);
              }
            },
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(AppIcons.back, size: 22, color: colors.brand),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Scholar ',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.brand,
                      ),
                    ),
                    TextSpan(
                      text: 'Wallet',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.accentGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 42),
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
                'Step ${_step + 1} of 2',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
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
                style: GoogleFonts.poppins(
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
          style: GoogleFonts.poppins(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.15,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
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
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: colors.textBody,
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Text(
                  'Sign In',
                  style: GoogleFonts.poppins(
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
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _topBar(context),
                      const SizedBox(height: 18),
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
