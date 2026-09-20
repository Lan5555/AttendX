import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/state/app_state.dart';
import '../../shared/models/user.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  UserRole _selectedRole = UserRole.student;
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _idController = TextEditingController(); // Student ID or Staff ID
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _departmentController = TextEditingController(text: 'Computer Science');
  final _facultyController = TextEditingController(text: 'Faculty of Computing');

  bool _isLoading = false;

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

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final appState = context.read<AppState>();
    final result = _selectedRole == UserRole.student
        ? await appState.authService.registerStudent(
            fullName: _fullNameController.text.trim(),
            studentId: _idController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            department: _departmentController.text.trim(),
            faculty: _facultyController.text.trim(),
          )
        : await appState.authService.registerLecturer(
            fullName: _fullNameController.text.trim(),
            staffId: _idController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            department: _departmentController.text.trim(),
            faculty: _facultyController.text.trim(),
          );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      appState.refreshSession();
      context.go(_selectedRole == UserRole.student ? '/student' : '/lecturer');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Registration failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = _selectedRole == UserRole.student;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('I am a', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _RoleTile(
                        label: 'Student',
                        icon: Icons.school_rounded,
                        selected: isStudent,
                        onTap: () => setState(() => _selectedRole = UserRole.student),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _RoleTile(
                        label: 'Lecturer',
                        icon: Icons.person_pin_rounded,
                        selected: !isStudent,
                        onTap: () => setState(() => _selectedRole = UserRole.lecturer),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Full Name',
                  controller: _fullNameController,
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: isStudent ? 'Student ID' : 'Staff ID',
                  controller: _idController,
                  prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your email';
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
                  validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Confirm Password',
                  controller: _confirmPasswordController,
                  isPassword: true,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  validator: (v) {
                    if (v != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Department',
                  controller: _departmentController,
                  prefixIcon: const Icon(Icons.account_balance_outlined, size: 20),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your department' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Faculty',
                  controller: _facultyController,
                  prefixIcon: const Icon(Icons.apartment_rounded, size: 20),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your faculty' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
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

class _RoleTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleTile({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.08) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 1.4),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textTertiary),
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
