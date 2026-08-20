import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/auth_service.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final canSignIn = auth.isConfigured && !auth.busy;

    return Scaffold(
      backgroundColor: kInk,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/icon/app_icon.png',
                        width: 36,
                        height: 36,
                        semanticLabel: 'DebtFold logo',
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'DebtFold',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 64),
                  const Text(
                    'DEBT PAYOFF PLANNER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: kAccentPale,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'See the move.\nThen make it.',
                    style: TextStyle(
                      fontSize: 42,
                      height: 1.08,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Compare payoff strategies, understand the tradeoff, and keep your plan moving.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFFB4C0B9),
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canSignIn ? auth.signIn : null,
                      child: auth.busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Sign in with WorkOS'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: auth.busy ? null : auth.continueAsGuest,
                      style: TextButton.styleFrom(
                        foregroundColor: kAccentPale,
                      ),
                      child: const Text('Continue without signing in'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your data stays on this device. You can sign in later to save it to your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFFB4C0B9),
                      height: 1.4,
                    ),
                  ),
                  if (!auth.isConfigured) ...[
                    const SizedBox(height: 20),
                    const _SetupNotice(),
                  ],
                  if (auth.isConfigured && auth.error != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      auth.error!,
                      style: const TextStyle(
                        color: Color(0xFFB3402E),
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupNotice extends StatelessWidget {
  const _SetupNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE8C4BC)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Auth is waiting for build settings.',
            style: TextStyle(
              color: Color(0xFFB3402E),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Restart Flutter with WORKOS_CLIENT_ID, AUTH_BACKEND_BASE_URL, and exactly one of WORKOS_PROVIDER, WORKOS_ORGANIZATION_ID, or WORKOS_CONNECTION_ID.',
            style: TextStyle(
              color: Color(0xFFB3402E),
              fontSize: 12,
              fontWeight: FontWeight.w300,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
