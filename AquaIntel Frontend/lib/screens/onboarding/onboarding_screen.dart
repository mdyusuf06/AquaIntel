import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_animations.dart';
import '../../widgets/aq_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isSignUp = false;
  String _selectedRole = 'Mission Operator';
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();

  static const _roles = ['Mission Operator', 'Survey Commander', 'Environmental Analyst', 'Port Authority', 'Coast Guard Officer'];

  @override
  void dispose() {
    _emailCtrl.dispose(); _passCtrl.dispose(); _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() => context.go('/');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero ──────────────────────────────────────────────────────
            Container(
              height: 260,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.xLarge)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.large),
                      ),
                      child: const Icon(Icons.waves_rounded, color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    Text('AquaIntel', style: AppTextStyles.headline.copyWith(color: Colors.white)),
                    const SizedBox(height: AppSpacing.s4),
                    Text('Marine AI Mission Platform', style: AppTextStyles.body.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ),

            // ── Form ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.s8),
                  // Toggle
                  Container(
                    decoration: BoxDecoration(color: AppColors.surfaceGray, borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Row(
                      children: [
                        _AuthTab(label: 'Sign In',  selected: !_isSignUp, onTap: () => setState(() => _isSignUp = false)),
                        _AuthTab(label: 'Sign Up',  selected: _isSignUp,  onTap: () => setState(() => _isSignUp = true)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s32),

                  if (_isSignUp) ...[
                    _InputField(controller: _nameCtrl, label: 'Full Name', icon: Icons.person_outline),
                    const SizedBox(height: AppSpacing.s16),
                  ],
                  _InputField(controller: _emailCtrl, label: 'Email / ID',         icon: Icons.email_outlined,    keyboard: TextInputType.emailAddress),
                  const SizedBox(height: AppSpacing.s16),
                  _InputField(controller: _passCtrl,  label: 'Password',            icon: Icons.lock_outline,      isPassword: true),
                  const SizedBox(height: AppSpacing.s24),

                  // Role Selector
                  Text('Select Role', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: AppSpacing.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedRole,
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                      style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                      items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setState(() => _selectedRole = v!),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s32),

                  AqButton(label: _isSignUp ? 'Create Account' : 'Sign In', isFullWidth: true, onPressed: _submit),
                  const SizedBox(height: AppSpacing.s16),

                  // Biometric
                  Center(
                    child: TextButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.fingerprint_rounded, color: AppColors.primaryBlue),
                      label: Text('Continue with Biometrics', style: AppTextStyles.body.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  // Organization
                  const SizedBox(height: AppSpacing.s32),
                  Center(
                    child: Text('Organization: Coast Guard Command — INS', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(height: AppSpacing.s40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AuthTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: selected ? [BoxShadow(color: AppColors.shadow, blurRadius: 8)] : null,
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: selected ? AppColors.primaryBlue : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboard;

  const _InputField({required this.controller, required this.label, required this.icon, this.isPassword = false, this.keyboard});

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.s8),
        TextField(
          controller: widget.controller,
          obscureText: widget.isPassword && _obscure,
          keyboardType: widget.keyboard,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            prefixIcon: Icon(widget.icon, color: AppColors.textSecondary, size: 20),
            suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.textSecondary),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
              : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2)),
          ),
        ),
      ],
    );
  }
}
