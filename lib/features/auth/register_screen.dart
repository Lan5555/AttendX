import 'dart:io';

import 'package:attendx/controllers/auth_controller.dart';
import 'package:attendx/services/auth_service.dart';
import 'package:attendx/services/biometric_service.dart';
import 'package:attendx/shared/models/lecturer.dart';
import 'package:attendx/shared/models/student.dart';
import 'package:attendx/shared/widgets/liveness_card.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_liveness_detection/flutter_liveness_detection.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/user.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  UserRole _selectedRole = UserRole.student;
  final _formKey = GlobalKey<FormState>();
  final _biometricService = BiometricService();

  final _fullNameController = TextEditingController();
  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _departmentController = TextEditingController(text: 'Computer Science');
  final _facultyController =
      TextEditingController(text: 'Faculty of Computing');
  final TextEditingController _titleController =
      TextEditingController(text: 'Dr');
  File? imageFile;

  bool _isLoading = false;

  bool _biometricSupported = false;
  bool _biometricCaptured = false;
  bool _capturingBiometric = false;
  String? _biometricToken;
  List<BiometricType> _availableBiometrics = [];
  FlutterSecureStorage? _storage;
  String? _livenessImageKey;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
    requestCameraPermission();
    _storage = const FlutterSecureStorage();
  }

  Future<void> requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enable Camera')));
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _idController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _departmentController.dispose();
    _facultyController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricSupport() async {
    final supported = await _biometricService.canUseBiometrics();
    final available = await _biometricService.getAvailableBiometrics();
    if (!mounted) return;
    setState(() {
      _biometricSupported = supported;
      _availableBiometrics = available;
    });
  }

  Future<void> _captureBiometric() async {
    setState(() => _capturingBiometric = true);

    final result = await _biometricService.captureBiometric(
      reason: 'Enroll your biometrics to secure your account and enable '
          'fast attendance check-in.',
    );

    if (!mounted) return;
    setState(() => _capturingBiometric = false);

    if (result.success) {
      setState(() {
        _biometricCaptured = true;
        _biometricToken = result.biometricToken;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric enrolled successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Biometric capture failed.'),
        ),
      );
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_biometricCaptured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enroll your biometrics to continue.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final payload = {
      "fullName": _fullNameController.text.trim(),
      "studentId": _idController.text.trim(),
      "email": _emailController.text.trim(),
      "password": _passwordController.text,
      "department": _departmentController.text.trim(),
      "faculty": _facultyController.text.trim(),
      "biometricToken": _livenessImageKey,
      "title": '${_titleController.text.trim()}.'
    };
    final auth = context.read<AuthController>();
    final result = _selectedRole == UserRole.student
        ? await AuthService.instance.registerStudent(payload)
        : await AuthService.instance.registerLecturer(
            {...payload, 'staffId': _idController.text.trim()});

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      final role = result.data['user']!['role'] as String;
      if (role == UserRole.student.name) {
        final user = Student.fromJson(result.data);
        auth.currentUser = user;
        await _storage!.write(key: 'accessToken', value: user.accessToken);
      } else {
        final user = Lecturer.fromJson(result.data);
        auth.currentUser = user;
        await _storage!.write(key: 'accessToken', value: user.accessToken);
      }
      context.go(
        _selectedRole == UserRole.student ? '/student' : '/lecturer',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // ── Hero ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _Hero(
                  role: _selectedRole,
                  onRoleChanged: (r) => setState(() => _selectedRole = r),
                ),
              ),

              // ── Biometric ────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  // child: _BiometricEnrollmentCard(
                  //   supported: _biometricSupported,
                  //   captured: _biometricCaptured,
                  //   capturing: _capturingBiometric,
                  //   availableBiometrics: _availableBiometrics,
                  //   onCapture: _captureBiometric,
                  // ),
                  child: LivenessCaptureCard(
                    onCaptured: (key, image) => setState(() {
                      _livenessImageKey = key;
                      _biometricCaptured = true;
                    }),
                    onCancelled: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Operation Cancelled')));
                    },
                    requiredCheck: false,
                  ),
                ),
              ),

              // ── Personal info ────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _Section(
                    title: 'Personal information',
                    icon: Icons.person_outline_rounded,
                    child: Column(
                      children: [
                        _Field(
                          label: 'Full name',
                          controller: _fullNameController,
                          hint: 'e.g. John Doe',
                          icon: Icons.badge_outlined,
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter your full name'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _Field(
                          label: _selectedRole == UserRole.student
                              ? 'Matriculation number'
                              : 'Staff ID',
                          controller: _idController,
                          hint: _selectedRole == UserRole.student
                              ? 'e.g. UJ/2022/NS/0032'
                              : 'e.g. UJ/45/SFS/3344',
                          icon: Icons.numbers_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'This field is required'
                              : null,
                        ),
                        if (_selectedRole == UserRole.lecturer) ...[
                          _Field(
                            label: 'Title',
                            controller: _titleController,
                            icon: Icons.title,
                          )
                        ],
                        const SizedBox(height: AppSpacing.md),
                        _Field(
                          label: 'Email',
                          controller: _emailController,
                          hint: 'you@university.edu',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Enter your email';
                            }
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _Field(
                          label: 'Department',
                          controller: _departmentController,
                          icon: Icons.account_balance_outlined,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter your department'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _Field(
                          label: 'Faculty',
                          controller: _facultyController,
                          icon: Icons.apartment_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter your faculty'
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Security ─────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _Section(
                    title: 'Security',
                    icon: Icons.lock_outline_rounded,
                    child: Column(
                      children: [
                        _Field(
                          label: 'Password',
                          controller: _passwordController,
                          hint: 'At least 6 characters',
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          validator: (v) => (v == null || v.length < 6)
                              ? 'At least 6 characters'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _Field(
                          label: 'Confirm password',
                          controller: _confirmPasswordController,
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          validator: (v) {
                            if (v != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Submit ───────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: .5),
                        disabledForegroundColor:
                            AppColors.onPrimary.withValues(alpha: .7),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 20),
                      label: Text(
                        _isLoading ? 'Creating account…' : 'Create Account',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Login link ───────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Already have an account? Log in'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// HERO — title + role selector
// ─────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  final UserRole role;
  final ValueChanged<UserRole> onRoleChanged;

  const _Hero({required this.role, required this.onRoleChanged});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isStudent = role == UserRole.student;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topPadding + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryLight.withValues(alpha: .16),
            AppColors.primaryLight.withValues(alpha: .04),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (Navigator.of(context).canPop())
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textPrimary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 22,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: AppColors.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Create Account',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Join AttendX to mark or manage attendance.',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: .9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Role selector
          const Text(
            'I am a',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _RoleTile(
                  label: 'Student',
                  subtitle: 'Mark attendance',
                  icon: Icons.school_rounded,
                  selected: isStudent,
                  onTap: () => onRoleChanged(UserRole.student),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _RoleTile(
                  label: 'Lecturer',
                  subtitle: 'Manage sessions',
                  icon: Icons.person_pin_rounded,
                  selected: !isStudent,
                  onTap: () => onRoleChanged(UserRole.lecturer),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ROLE TILE
// ─────────────────────────────────────────────────────────────────────
class _RoleTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.surface
          : AppColors.surface.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.outline.withValues(alpha: .6),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.onPrimary : AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SECTION WRAPPER
// ─────────────────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// FIELD
// ─────────────────────────────────────────────────────────────────────
class _Field extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.isPassword ? _obscured : false,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          validator: widget.validator,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: widget.icon != null
                ? Icon(
                    widget.icon,
                    size: 18,
                    color: AppColors.textTertiary,
                  )
                : null,
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.4,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// BIOMETRIC ENROLLMENT CARD
// ─────────────────────────────────────────────────────────────────────
class _BiometricEnrollmentCard extends StatelessWidget {
  final bool supported;
  final bool captured;
  final bool capturing;
  final List<BiometricType> availableBiometrics;
  final VoidCallback onCapture;

  const _BiometricEnrollmentCard({
    required this.supported,
    required this.captured,
    required this.capturing,
    required this.availableBiometrics,
    required this.onCapture,
  });

  IconData _biometricIcon() {
    if (availableBiometrics.contains(BiometricType.face)) {
      return Icons.face_rounded;
    }
    return Icons.fingerprint_rounded;
  }

  String _biometricLabel() {
    if (availableBiometrics.contains(BiometricType.face)) return 'Face ID';
    if (availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    }
    return 'Biometric';
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = captured ? AppColors.success : AppColors.warning;
    final accentBg = captured ? AppColors.successBg : AppColors.warningBg;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color:
              supported ? accentColor.withValues(alpha: .3) : AppColors.outline,
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  captured ? Icons.verified_user_rounded : _biometricIcon(),
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      captured ? 'Liveness enrolled' : 'Biometric (required)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: captured
                            ? AppColors.success
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      captured
                          ? 'Linked to your account'
                          : 'Secure your account',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (captured)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 22,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            captured
                ? 'Your ${_biometricLabel()} is linked to your account. '
                    'You can use it for attendance check-in and secure login.'
                : 'Enroll your ${_biometricLabel().toLowerCase()} to secure '
                    'your account and enable one-tap attendance.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!supported)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Biometrics not available on this device. You can '
                      'still continue, but attendance verification will '
                      'require manual check-in.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.warning,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: capturing ? null : onCapture,
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      captured ? AppColors.primary : AppColors.textPrimary,
                  side: BorderSide(
                    color: captured
                        ? AppColors.primary.withValues(alpha: .4)
                        : AppColors.outline,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                icon: capturing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        captured ? Icons.refresh_rounded : _biometricIcon(),
                        size: 18,
                      ),
                label: Text(
                  capturing
                      ? 'Capturing…'
                      : captured
                          ? 'Re-enroll biometric'
                          : 'Enroll ${_biometricLabel()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
