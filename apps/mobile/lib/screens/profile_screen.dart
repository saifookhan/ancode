import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared/shared.dart';

import '../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'plan_selection_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(User user) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'name': _nameController.text.trim(),
            'surname': _surnameController.text.trim(),
          },
        ),
      );
      await context.read<AuthService>().refreshProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const LoginScreen();
        }
        final user = session.user;
        final metadata = user.userMetadata ?? <String, dynamic>{};
        _nameController.text = (_nameController.text.isEmpty ? (metadata['name']?.toString() ?? '') : _nameController.text);
        _surnameController.text = (_surnameController.text.isEmpty ? (metadata['surname']?.toString() ?? '') : _surnameController.text);
        final email = user.email ?? '';
        if (_emailController.text != email) _emailController.text = email;
        final rawPlan = user.userMetadata?['plan']?.toString().toLowerCase() ?? 'free';
        final displayPlan = rawPlan.isEmpty ? 'Free' : '${rawPlan[0].toUpperCase()}${rawPlan.substring(1)}';

        return Scaffold(
          backgroundColor: AppColors.biancoOttico,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    'Personal profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1E2230),
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'View and edit your user data',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF525866),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE5E5E8)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _FieldLabel('Name *'),
                        const SizedBox(height: 10),
                        _ProfileField(controller: _nameController, hint: 'Enter your name'),
                        const SizedBox(height: 18),
                        const _FieldLabel('Surname *'),
                        const SizedBox(height: 10),
                        _ProfileField(controller: _surnameController, hint: 'Enter your surname'),
                        const SizedBox(height: 18),
                        const _FieldLabel('E-mail *'),
                        const SizedBox(height: 10),
                        _ProfileField(controller: _emailController, readOnly: true),
                        const SizedBox(height: 18),
                        const _FieldLabel('Our plan'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 54,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F8FB),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFD8D8E1)),
                                ),
                                child: Text(
                                  displayPlan,
                                  style: const TextStyle(
                                    color: Color(0xFF2E3440),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 54,
                              child: FilledButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const PlanSelectionScreen(),
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF9A80E8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text(
                                  'Upgrade',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 58,
                          child: FilledButton(
                            onPressed: _isSaving ? null : () => _saveProfile(user),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF9A80E8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text(
                                    'Save changes',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        const Divider(height: 1, color: Color(0xFFE0E0E0)),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            height: 56,
                            width: 270,
                            child: FilledButton(
                              onPressed: () async {
                                await context.read<AuthService>().signOut();
                                if (context.mounted) {
                                  await context.read<AuthService>().refreshProfile();
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFF16D79),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text(
                                'Logout your account',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
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
          ),
        );
      },
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF2E3440),
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    this.hint,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String? hint;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFA8A8B2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD8D8E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFBFAEF5), width: 1.4),
        ),
      ),
    );
  }
}
