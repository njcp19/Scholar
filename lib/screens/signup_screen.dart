import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../widgets/widgets.dart';
import '../widgets/app_icons.dart';

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

  final _name = TextEditingController();
  final _studentNo = TextEditingController();
  final _university = TextEditingController();
  final _program = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String? _yearLevel;
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _agreed = false;
  bool _busy = false;
  final Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _name.dispose();
    _studentNo.dispose();
    _university.dispose();
    _program.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_name.text.trim().isEmpty ||
        _studentNo.text.trim().isEmpty ||
        _university.text.trim().isEmpty ||
        _program.text.trim().isEmpty ||
        _yearLevel == null ||
        _email.text.trim().isEmpty ||
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

  void _showFieldErrors() {
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
    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors);
    });
  }

  void _clearFieldError(String key) {
    if (_fieldErrors.containsKey(key)) {
      setState(() => _fieldErrors.remove(key));
    }
  }

  Future<void> _signup() async {
    final error = _validate();
    if (error != null) {
      _showFieldErrors();
      showMsg(context, error, error: true);
      return;
    }
    _clearAllFieldErrors();
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      final messenger = ScaffoldMessenger.of(context);
      await state.auth.signUp(
        fullName: _name.text,
        email: _email.text,
        password: _password.text,
        studentNumber: _studentNo.text,
        university: _university.text,
        program: _program.text,
        yearLevel: _yearLevel!,
        declaredScholar: true,
        scholarshipName: 'Existing scholarship',
        scholarshipReference: '',
      );
      // AuthGate opens the verification status screen for this signed-in account.
      if (mounted) {
        Navigator.pop(context);
      }
      messenger.showSnackBar(const SnackBar(
        content: Text('Registration submitted for admin verification.'),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) {
        showMsg(context, context.read<AppState>().auth.friendlyError(e),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearAllFieldErrors() {
    if (_fieldErrors.isNotEmpty) {
      setState(_fieldErrors.clear);
    }
  }

  // ---- UI helpers ---------------------------------------------------------

  TextStyle _label(BuildContext context) => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.colors.textLabel,
      );

  InputDecoration _decoration(BuildContext context, String hint, IconData icon,
          {Widget? suffix, String? error}) =>
      InputDecoration(
        filled: true,
        fillColor: context.colors.surface,
        hintText: hint,
        hintStyle:
            GoogleFonts.poppins(fontSize: 14, color: context.colors.hint),
        prefixIcon: Icon(icon, size: 18, color: context.colors.textBody),
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        errorText: error,
        errorStyle:
            GoogleFonts.poppins(fontSize: 12, color: AppTheme.dangerRed),
        border: _border(context.colors.borderSoft),
        enabledBorder: _border(context.colors.borderSoft),
        focusedBorder: _border(context.colors.brand, width: 1.5),
        errorBorder: _border(AppTheme.dangerRed),
        focusedErrorBorder: _border(context.colors.brand, width: 1.5),
      );

  OutlineInputBorder _border(Color c, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: width),
      );

  Widget _field(BuildContext context, String label, Widget input) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _label(context)),
            const SizedBox(height: 6),
            input,
          ],
        ),
      );

  Widget _text(BuildContext context, String label, String key,
          TextEditingController controller, String hint, IconData icon,
          {TextInputType? type,
          TextCapitalization cap = TextCapitalization.none,
          TextInputAction action = TextInputAction.next}) =>
      _field(
        context,
        label,
        TextField(
          controller: controller,
          keyboardType: type,
          textInputAction: action,
          textCapitalization: cap,
          onChanged: (_) => _clearFieldError(key),
          style: GoogleFonts.poppins(
              fontSize: 14, color: context.colors.textPrimary),
          decoration:
              _decoration(context, hint, icon, error: _fieldErrors[key]),
        ),
      );

  Widget _passwordField(BuildContext context, String label, String key,
          TextEditingController controller, bool obscure, VoidCallback toggle,
          {required TextInputAction action}) =>
      _field(
        context,
        label,
        TextField(
          controller: controller,
          obscureText: obscure,
          textInputAction: action,
          onChanged: (_) => _clearFieldError(key),
          style: GoogleFonts.poppins(
              fontSize: 14, color: context.colors.textPrimary),
          decoration: _decoration(
            context,
            '••••••••••••••••',
            AppIcons.lock,
            error: _fieldErrors[key],
            suffix: IconButton(
              icon: Icon(obscure ? AppIcons.eye : AppIcons.eyeOff,
                  size: 18, color: context.colors.textBody),
              onPressed: toggle,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar: back button + brand title
              Row(
                children: [
                  Material(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.borderSoft),
                        ),
                        child: Icon(
                          AppIcons.back,
                          size: 22,
                          color: colors.brand,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: 'Scholar ',
                              style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: colors.brand)),
                          TextSpan(
                              text: 'Wallet',
                              style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accentGold)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40), // balance the back button
                ],
              ),
              const SizedBox(height: 24),
              Text('Create Student Account',
                  style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: colors.brand)),
              const SizedBox(height: 6),
              Text(
                'Register with your academic details to start receiving and tracking your scholarships.',
                style: GoogleFonts.poppins(
                    fontSize: 14, height: 1.5, color: colors.textBody),
              ),
              const SizedBox(height: 22),

              _text(context, 'Full Name', 'name', _name, 'Juan Dela Cruz',
                  AppIcons.user,
                  cap: TextCapitalization.words),
              _text(context, 'Student Number', 'studentNo', _studentNo,
                  '20243771', AppIcons.idCard,
                  type: TextInputType.number),
              _text(context, 'University / College', 'university', _university,
                  'Urdaneta City University', AppIcons.school,
                  cap: TextCapitalization.words),
              _text(context, 'Program / Course', 'program', _program,
                  'B.S. Information Technology', AppIcons.book,
                  cap: TextCapitalization.words),

              _field(
                context,
                'Year Level',
                DropdownButtonFormField<String>(
                  initialValue: _yearLevel,
                  isExpanded: true,
                  icon: Icon(AppIcons.chevronDown, color: colors.textBody),
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: colors.textPrimary),
                  decoration: _decoration(
                    context,
                    'Select year level',
                    AppIcons.award,
                    error: _fieldErrors['yearLevel'],
                  ),
                  items: _yearLevels
                      .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _yearLevel = v);
                    _clearFieldError('yearLevel');
                  },
                ),
              ),

              _text(context, 'School Email Address', 'email', _email,
                  'juandelacruz12@gmail.com', AppIcons.mail,
                  type: TextInputType.emailAddress),
              _passwordField(context, 'Password', 'password', _password,
                  _obscurePw, () => setState(() => _obscurePw = !_obscurePw),
                  action: TextInputAction.next),
              _passwordField(
                  context,
                  'Confirm Password',
                  'confirm',
                  _confirm,
                  _obscureConfirm,
                  () => setState(() => _obscureConfirm = !_obscureConfirm),
                  action: TextInputAction.done),

              // Terms
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _agreed,
                      activeColor: colors.brand,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      side: BorderSide(color: colors.brand),
                      onChanged: (v) {
                        setState(() => _agreed = v ?? false);
                        _clearFieldError('terms');
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: GoogleFonts.poppins(
                            fontSize: 12, height: 1.5, color: colors.textBody),
                        children: [
                          const TextSpan(
                              text: 'I agree to the Scholar Wallet '),
                          TextSpan(
                              text: 'Terms of Service',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.brand)),
                          const TextSpan(text: ' and '),
                          TextSpan(
                              text: 'Privacy Policy',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.brand)),
                          const TextSpan(text: ' for financial disbursement.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_fieldErrors['terms'] != null)
                Padding(
                  padding: const EdgeInsets.only(left: 34, top: 4),
                  child: Text(
                    _fieldErrors['terms']!,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppTheme.dangerRed),
                  ),
                ),
              const SizedBox(height: 24),

              // Create Account button (pill with soft shadow)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: colors.brand.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _busy ? null : _signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: colors.onHeader,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _busy
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: colors.onHeader))
                      : Text('Create Account',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: colors.textBody)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text('Sign In',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.brand)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
