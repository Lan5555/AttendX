import 'package:attendx/controllers/auth_controller.dart';
import 'package:attendx/services/biometric_service.dart';
import 'package:attendx/shared/models/lecturer.dart';
import 'package:attendx/shared/models/student.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/state/app_state.dart';
import '../../shared/models/user.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ---------- Form state ----------
  UserRole _selectedRole = UserRole.student;
  final _formKey = GlobalKey<FormState>();
  final _biometricService = BiometricService();

  final _fullNameController = TextEditingController();
  final _idController = TextEditingController(); // Student ID or Staff ID
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _departmentController = TextEditingController(text: 'Computer Science');
  final _facultyController =
      TextEditingController(text: 'Faculty of Computing');

  bool _isLoading = false;

  // ---------- Biometric state ----------
  bool _biometricSupported = false;
  bool _biometricCaptured = false;
  bool _capturingBiometric = false;
  String? _biometricToken;
  List<BiometricType> _availableBiometrics = [];
  FlutterSecureStorage? _storage;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
    _storage = const FlutterSecureStorage();
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

  // ---------- Biometric helpers ----------
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

  // ---------- Registration ----------
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    // Require biometric enrollment before proceeding.
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
      "biometricToken": _biometricToken,
    };
    final auth = context.read<AuthController>();
    final result = _selectedRole == UserRole.student
        ? await AuthService.instance.registerStudent(payload)
        : await AuthService.instance.registerLecturer(
            {...payload, 'staffId': _idController.text.trim()});

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      //appState.refreshSession();
      final role = result.data['user']!.role;
      if (role == UserRole.student) {
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
        SnackBar(
          content: Text(
            result.message,
          ),
        ),
      );
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final isStudent = _selectedRole == UserRole.student;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- Role selector ----------
                Text('I am a', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _RoleTile(
                        label: 'Student',
                        icon: Icons.school_rounded,
                        selected: isStudent,
                        onTap: () =>
                            setState(() => _selectedRole = UserRole.student),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _RoleTile(
                        label: 'Lecturer',
                        icon: Icons.person_pin_rounded,
                        selected: !isStudent,
                        onTap: () =>
                            setState(() => _selectedRole = UserRole.lecturer),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // ---------- Biometric enrollment ----------
                _BiometricEnrollmentCard(
                  supported: _biometricSupported,
                  captured: _biometricCaptured,
                  capturing: _capturingBiometric,
                  availableBiometrics: _availableBiometrics,
                  onCapture: _captureBiometric,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ---------- Form fields ----------
                AppTextField(
                  label: 'Full Name',
                  controller: _fullNameController,
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your full name'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  label: isStudent ? 'MAT NO' : 'Staff ID',
                  controller: _idController,
                  prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'This field is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter your email';
                    }
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  label: 'Password',
                  controller: _passwordController,
                  isPassword: true,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'At least 6 characters'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  label: 'Confirm Password',
                  controller: _confirmPasswordController,
                  isPassword: true,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  validator: (v) {
                    if (v != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  label: 'Department',
                  controller: _departmentController,
                  prefixIcon:
                      const Icon(Icons.account_balance_outlined, size: 20),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your department'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  label: 'Faculty',
                  controller: _facultyController,
                  prefixIcon: const Icon(Icons.apartment_rounded, size: 20),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your faculty'
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ---------- Submit ----------
                AppButton(
                  label: 'Create Account',
                  isLoading: _isLoading,
                  onPressed: _handleRegister,
                  width: double.infinity,
                ),
                const SizedBox(height: AppSpacing.md),

                Center(
                  child: TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Already have an account? Log in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Role tile
// ---------------------------------------------------------------------------
class _RoleTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: .08)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Biometric enrollment card
// ---------------------------------------------------------------------------
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
    if (availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint_rounded;
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: captured
            ? AppColors.primary.withValues(alpha: .06)
            : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: captured ? AppColors.primary : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                captured ? Icons.verified_user_rounded : _biometricIcon(),
                color: captured ? AppColors.primary : AppColors.textTertiary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  captured
                      ? 'Biometric Enrolled'
                      : 'Biometric Enrollment (Required)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color:
                        captured ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            captured
                ? 'Your ${_biometricLabel()} is linked to your account. '
                    'You can now use it for attendance check-in and secure login.'
                : 'Enroll your ${_biometricLabel().toLowerCase()} to secure '
                    'your account and enable one-tap attendance.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!supported)
            const Text(
              'Biometrics not available on this device. You can still '
              'continue, but attendance verification will require manual '
              'check-in.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: capturing ? null : onCapture,
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
                      ? 'Capturing...'
                      : captured
                          ? 'Re-enroll Biometric'
                          : 'Enroll ${_biometricLabel()}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
