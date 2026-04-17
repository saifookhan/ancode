import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shared/shared.dart';

import '../services/auth_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/admin/admin_shell.dart';

/// Top bar: asterisk + ANCODE left; FAQ, Idee di utilizzo, Dashboard, Profilo, Logout right
class LandingHeader extends StatelessWidget implements PreferredSizeWidget {
  const LandingHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.biancoOttico,
        border: Border(
          bottom: BorderSide(color: AppColors.bluPolvere.withOpacity(0.3)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Text(
                '*',
                style: AppTypography.titleExtraBold(
                  color: AppColors.azzurroCiano,
                  fontSize: 24,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ANCODE',
                style: AppTypography.titleExtraBold(
                  color: AppColors.bluUniverso,
                  fontSize: 22,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              _NavLink(label: 'FAQ', onTap: () {}),
              _NavLink(label: 'Idee di utilizzo', onTap: () {}),
              Consumer<AuthService>(
                builder: (context, auth, _) {
                  if (!auth.isLoggedIn) {
                    return _NavLink(
                      label: 'Accedi',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                    );
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NavLink(
                        label: 'Dashboard',
                        onTap: () {
                          // Switch to main shell dashboard tab
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        },
                      ),
                      _NavLink(label: 'Profilo', onTap: () {}),
                      if (auth.profile?.isAdmin == true)
                        _NavLink(
                          label: 'Admin',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminShell()),
                          ),
                        ),
                      _NavLink(
                        label: 'Logout',
                        onTap: () => auth.signOut(),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: InkWell(
        onTap: onTap,
        child: Text(
          label,
          style: AppTypography.bodySemiBoldItalic(
            color: AppColors.bluPolvere,
            fontSize: 14,
          ).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: AppColors.bluPolvere,
          ),
        ),
      ),
    );
  }
}
