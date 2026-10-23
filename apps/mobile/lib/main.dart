import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'design/components.dart';
import 'design/tokens.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey =
    String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _appVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0+1');
const _webPreview = bool.fromEnvironment('WEB_PREVIEW', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_webPreview &&
      _supabaseUrl.isNotEmpty &&
      _supabasePublishableKey.isNotEmpty) {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
    );
  }
  runApp(const SocietyWashApp());
}

class SocietyWashApp extends StatelessWidget {
  const SocietyWashApp({super.key, this.previewMode = _webPreview});
  final bool previewMode;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Society Wash',
        theme: washTheme(),
        home: _EntryScreen(previewMode: previewMode),
      );
}

class _EntryScreen extends StatefulWidget {
  const _EntryScreen({required this.previewMode});
  final bool previewMode;

  @override
  State<_EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<_EntryScreen> {
  String? _role;
  bool _registering = true;
  String? _minimumVersion;
  bool _versionCheckFailed = false;

  @override
  void initState() {
    super.initState();
    if (!widget.previewMode &&
        _supabaseUrl.isNotEmpty &&
        _supabasePublishableKey.isNotEmpty) {
      _loadMinimumVersion();
    }
  }

  Future<void> _loadMinimumVersion() async {
    try {
      final result =
          await Supabase.instance.client.rpc('minimum_android_app_version');
      if (mounted) {
        setState(() => _minimumVersion = result as String? ?? '0.1.0+1');
      }
    } catch (_) {
      if (mounted) setState(() => _versionCheckFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.previewMode) {
      return _role == null
          ? _RoleChoiceScreen(
              previewMode: true,
              onChoose: (role, registering) => setState(() {
                _role = role;
                _registering = registering;
              }),
            )
          : _PhoneScreen(
              role: _role!,
              registering: _registering,
              onBack: () => setState(() => _role = null),
              previewMode: true,
            );
    }
    if (_supabaseUrl.isEmpty || _supabasePublishableKey.isEmpty) {
      return const _SetupScreen();
    }
    if (_versionCheckFailed) {
      return _VersionCheckErrorScreen(onRetry: () {
        setState(() {
          _versionCheckFailed = false;
          _minimumVersion = null;
        });
        _loadMinimumVersion();
      });
    }
    if (_minimumVersion == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (isVersionOlderThan(_appVersion, _minimumVersion!)) {
      return const _UpdateRequiredScreen();
    }
    if (Supabase.instance.client.auth.currentSession != null) {
      return const _SignedInScreen();
    }
    return _role == null
        ? _RoleChoiceScreen(
            onChoose: (role, registering) => setState(() {
              _role = role;
              _registering = registering;
            }),
          )
        : _PhoneScreen(
            role: _role!,
            registering: _registering,
            onBack: () => setState(() => _role = null),
          );
  }
}

bool isVersionOlderThan(String current, String minimum) {
  List<int> parts(String version) => version
      .split('+')
      .first
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
  final currentParts = parts(current);
  final minimumParts = parts(minimum);
  for (var i = 0; i < 3; i++) {
    final a = i < currentParts.length ? currentParts[i] : 0;
    final b = i < minimumParts.length ? minimumParts[i] : 0;
    if (a != b) return a < b;
  }
  final currentBuild = int.tryParse(current.split('+').last) ?? 0;
  final minimumBuild = int.tryParse(minimum.split('+').last) ?? 0;
  return currentBuild < minimumBuild;
}

class _UpdateRequiredScreen extends StatelessWidget {
  const _UpdateRequiredScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(WashSpace.lg),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.system_update, size: 52, color: WashColors.brand),
                SizedBox(height: WashSpace.md),
                Text('Please update the app to continue.',
                    textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      );
}

class _VersionCheckErrorScreen extends StatelessWidget {
  const _VersionCheckErrorScreen({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(WashSpace.lg),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.wifi_off, size: 48, color: WashColors.muted),
                const SizedBox(height: WashSpace.md),
                const Text(
                    'Could not check for an app update. Check your connection.',
                    textAlign: TextAlign.center),
                const SizedBox(height: WashSpace.md),
                ElevatedButton(
                    onPressed: onRetry, child: const Text('Try again')),
              ]),
            ),
          ),
        ),
      );
}

class _SetupScreen extends StatelessWidget {
  const _SetupScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(WashSpace.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: const WashSectionCard(
                  child: Column(
                    children: [
                      Icon(Icons.local_car_wash,
                          size: 52, color: WashColors.brand),
                      SizedBox(height: WashSpace.md),
                      Text('Society Wash',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700)),
                      SizedBox(height: WashSpace.sm),
                      Text(
                          'Connect this app to your Supabase project to sign in.',
                          textAlign: TextAlign.center),
                      SizedBox(height: WashSpace.md),
                      SelectableText(
                          'Run with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.',
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _RoleChoiceScreen extends StatelessWidget {
  const _RoleChoiceScreen({required this.onChoose, this.previewMode = false});
  final void Function(String role, bool registering) onChoose;
  final bool previewMode;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(WashSpace.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.local_car_wash,
                        size: 56, color: WashColors.brand),
                    const SizedBox(height: WashSpace.md),
                    Text('Society Wash',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: WashSpace.sm),
                    Text('Your society car wash, made simple.',
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center),
                    const SizedBox(height: WashSpace.xl),
                    Text('How will you use Society Wash?',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: WashSpace.md),
                    _RoleButton(
                      icon: Icons.directions_car,
                      title: 'Customer',
                      subtitle: 'Book and manage car washes',
                      onRegister: () => onChoose('customer', true),
                      onLogin: () => onChoose('customer', false),
                    ),
                    const SizedBox(height: WashSpace.md),
                    _RoleButton(
                      icon: Icons.cleaning_services,
                      title: 'Washer',
                      subtitle: 'Register or sign in to work',
                      onRegister: () => onChoose('washer', true),
                      onLogin: () => onChoose('washer', false),
                    ),
                    const SizedBox(height: WashSpace.md),
                    const Text('Your account type cannot be changed later.',
                        textAlign: TextAlign.center),
                    if (previewMode) ...[
                      const SizedBox(height: WashSpace.md),
                      const WashStatus(
                        label: 'Preview only · sign-in is not connected',
                        color: WashColors.warning,
                        icon: Icons.visibility_outlined,
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

class _RoleButton extends StatelessWidget {
  const _RoleButton(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onRegister,
      required this.onLogin});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onRegister;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(WashSpace.md),
          child: Row(
            children: [
              Icon(icon, size: 32, color: WashColors.brand),
              const SizedBox(width: WashSpace.md),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    Text(subtitle),
                    Wrap(spacing: WashSpace.sm, children: [
                      TextButton(
                          onPressed: onRegister, child: const Text('Register')),
                      TextButton(
                          onPressed: onLogin, child: const Text('Log in')),
                    ]),
                  ])),
            ],
          ),
        ),
      );
}

class _PhoneScreen extends StatefulWidget {
  const _PhoneScreen({
    required this.role,
    required this.registering,
    required this.onBack,
    this.previewMode = false,
  });
  final String role;
  final bool registering;
  final VoidCallback onBack;
  final bool previewMode;

  @override
  State<_PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<_PhoneScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  String get _e164 {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    return _phone.text.trim();
  }

  Future<void> _sendCode() async {
    if (_e164.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      var deviceId = preferences.getString('otp_rate_limit_device_id');
      if (deviceId == null) {
        final random = Random.secure();
        deviceId = List.generate(
          32,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        await preferences.setString('otp_rate_limit_device_id', deviceId);
      }
      await Supabase.instance.client.functions.invoke(
        'request-phone-otp',
        body: {
          'phone': _e164,
          'role': widget.role,
          'deviceId': deviceId,
          'registering': widget.registering,
        },
      );
      if (mounted) setState(() => _codeSent = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not send the code. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth
          .verifyOTP(phone: _e164, token: _otp.text.trim(), type: OtpType.sms);
      if (mounted) setState(() {});
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Could not verify the code. Check it and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            leading: BackButton(onPressed: widget.onBack),
            title: Text(
                '${widget.role == 'customer' ? 'Customer' : 'Washer'} sign in')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(WashSpace.lg),
            children: [
              Text(_codeSent ? 'Enter your code' : 'Continue with your phone',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: WashSpace.sm),
              Text(_codeSent
                  ? 'We sent a one-time code to $_e164.'
                  : 'We will text you a one-time verification code to ${widget.registering ? 'create your account' : 'sign in'}.'),
              const SizedBox(height: WashSpace.lg),
              if (!_codeSent)
                TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                        labelText: 'Phone number',
                        hintText: '+91 98765 43210',
                        prefixIcon: Icon(Icons.phone))),
              if (_codeSent)
                TextField(
                    controller: _otp,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 6,
                    decoration: const InputDecoration(
                        labelText: '6-digit code',
                        prefixIcon: Icon(Icons.lock_outline))),
              if (_error != null) ...[
                const SizedBox(height: WashSpace.sm),
                Text(_error!, style: const TextStyle(color: WashColors.danger))
              ],
              const SizedBox(height: WashSpace.md),
              ElevatedButton(
                  onPressed: _busy || widget.previewMode
                      ? null
                      : (_codeSent ? _verifyCode : _sendCode),
                  child: Text(widget.previewMode
                      ? 'Preview only'
                      : _busy
                          ? 'Please wait…'
                          : (_codeSent ? 'Verify code' : 'Send code'))),
              if (_codeSent)
                TextButton(
                    onPressed: _busy ? null : _sendCode,
                    child: const Text('Send a new code')),
              const SizedBox(height: WashSpace.md),
              const Text('Your phone number is used for account verification.',
                  textAlign: TextAlign.center),
              if (widget.previewMode) ...[
                const SizedBox(height: WashSpace.md),
                const WashStatus(
                  label: 'Preview only · OTP delivery is disabled',
                  color: WashColors.warning,
                  icon: Icons.visibility_outlined,
                ),
              ],
            ],
          ),
        ),
      );
}

class _SignedInScreen extends StatelessWidget {
  const _SignedInScreen();

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(WashSpace.lg),
            child: FutureBuilder(
              future: client
                  .from('profiles')
                  .select('role')
                  .eq('id', userId)
                  .single(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const CircularProgressIndicator();
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Text(
                      'Your account could not be loaded. Please try again.');
                }
                final washer = snapshot.data!['role'] == 'washer';
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(washer ? Icons.hourglass_top : Icons.verified_user,
                      size: 48, color: WashColors.brand),
                  const SizedBox(height: WashSpace.md),
                  Text(washer ? 'Waiting for approval' : 'Phone verified',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: WashSpace.sm),
                  Text(
                      washer
                          ? 'Your registration is ready for the business to review.'
                          : 'Your account is verified. Customer profile setup will continue here.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: WashSpace.lg),
                  OutlinedButton(
                      onPressed: () async => client.auth.signOut(),
                      child: const Text('Sign out')),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }
}
