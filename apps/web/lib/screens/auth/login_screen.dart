import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  SupabaseClient? get _authClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Please enter both email and password.');
      return;
    }
    setState(() {
      _error = null;
      _isLoading = true;
    });
    final client = _authClient;
    if (client == null) {
      setState(() {
        _isLoading = false;
        _error = 'Authentication service is not ready. Please reload and try again.';
      });
      return;
    }
    try {
      await client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        await Provider.of<AuthService>(context, listen: false).refreshProfile();
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      final message = e.toString();
      if (mounted) {
        setState(
          () => _error = message.contains('LateInitializationError')
              ? 'Authentication service is not ready. Please reload and try again.'
              : message,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = Colors.black;
    final mutedText = const Color(0xFF8C8C9A);
    final cardBorder = const Color(0xFFE4E4E8);
    final fieldBorder = const Color(0xFFD9D9DE);
    final signInPurple = const Color(0xFF9A80E8);
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 390;
    final wide = screenWidth >= 900;
    final contentWidth = wide ? 760.0 : 640.0;
    final titleSize = compact ? 42.0 : 56.0;
    final heroSize = compact ? 24.0 : 34.0;
    final bodySize = compact ? 15.0 : 20.0;
    final labelSize = compact ? 16.0 : 18.0;

    return Scaffold(
      backgroundColor: AppColors.biancoOttico,
      appBar: AppBar(
        backgroundColor: AppColors.biancoOttico,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Image.asset('assets/logo_mark.png', width: 34, height: 34, fit: BoxFit.contain),
        ),
        leadingWidth: 58,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ANCODE',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleExtraBold(
                      color: titleColor,
                      fontSize: titleSize,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'L I N K*  Y O U R  L I N K',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleExtraBold(
                      color: titleColor,
                      fontSize: compact ? 10 : 12,
                      letterSpacing: compact ? 2.4 : 3.2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'L1NK* YOUR LINK',
                    textAlign: TextAlign.center,
                    style: AppTypography.subtitleSemiBold(
                      color: mutedText,
                      fontSize: heroSize,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'New here? ',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyRegular(color: mutedText, fontSize: bodySize),
                      ),
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                ),
                        child: Text(
                          'Create an account',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySemiBoldItalic(color: signInPurple, fontSize: bodySize),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Email *',
                          style: AppTypography.bodyRegular(
                            color: const Color(0xFF2E3440),
                            fontSize: labelSize,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _emailController,
                          style: AppTypography.bodyRegular(color: Colors.black87, fontSize: bodySize),
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'name@email.com',
                            hintStyle: AppTypography.bodyRegular(
                              color: const Color(0xFFA8A8B2),
                              fontSize: bodySize,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: fieldBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.lavanda, width: 1.4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Password *',
                          style: AppTypography.bodyRegular(
                            color: const Color(0xFF2E3440),
                            fontSize: labelSize,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _passwordController,
                          style: AppTypography.bodyRegular(color: Colors.black87, fontSize: bodySize),
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            hintStyle: AppTypography.bodyRegular(
                              color: const Color(0xFFA8A8B2),
                              fontSize: bodySize,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: fieldBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.lavanda, width: 1.4),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: mutedText,
                              ),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                        const SizedBox(height: 24),
                        LimeRailPillButton(
                          onPressed: _isLoading ? null : _submit,
                          loading: _isLoading,
                          label: 'Sign in',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Forgot your password?',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySemiBoldItalic(
                            color: Colors.black.withOpacity(0.9),
                            fontSize: labelSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Demo: admin@ancode.com / admin123 o user@example.com / user123',
                    textAlign: TextAlign.center,
                    style: AppTypography.captionLight(
                      color: Colors.black.withOpacity(0.75),
                      fontSize: compact ? 13 : 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
