import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (!widget.previewMode &&
        _supabaseUrl.isNotEmpty &&
        _supabasePublishableKey.isNotEmpty) {
      _authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        if (mounted) setState(() {});
      });
    }
    if (!widget.previewMode &&
        _supabaseUrl.isNotEmpty &&
        _supabasePublishableKey.isNotEmpty) {
      _loadMinimumVersion();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
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

  void _showPreviewNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'OTP sign-in is not connected in this preview, so no code can be sent.',
        ),
      ),
    );
  }

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
                  onPressed: _busy
                      ? null
                      : widget.previewMode
                          ? _showPreviewNotice
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
    return FutureBuilder(
      future: client
          .from('profiles')
          .select('role, full_name, society_id')
          .eq('id', userId)
          .single(),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (profileSnapshot.hasError || !profileSnapshot.hasData) {
          return const Scaffold(
              body: Center(
            child: Text('Your account could not be loaded. Please try again.'),
          ));
        }

        final profile = profileSnapshot.data!;
        if (profile['role'] != 'washer') {
          return const _AccountStatusScreen(
            icon: Icons.verified_user,
            title: 'Phone verified',
            message:
                'Your account is verified. Customer profile setup will continue here.',
          );
        }

        return FutureBuilder(
          future: client
              .from('washers')
              .select('status')
              .eq('profile_id', userId)
              .maybeSingle(),
          builder: (context, washerSnapshot) {
            if (washerSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            if (washerSnapshot.hasError) {
              return const Scaffold(
                  body: Center(
                child: Text(
                    'Your registration could not be loaded. Please try again.'),
              ));
            }
            final washer = washerSnapshot.data;
            if (washer == null) {
              return _WasherRegistrationScreen(
                initialName: profile['full_name'] == 'New member'
                    ? ''
                    : profile['full_name'] as String,
                initialSocietyId: profile['society_id'] as String?,
              );
            }
            switch (washer['status']) {
              case 'pending':
                return const _AccountStatusScreen(
                  icon: Icons.hourglass_top,
                  title: 'Waiting for approval',
                  message:
                      'The business is reviewing your registration. You will not receive jobs until it is approved.',
                );
              case 'approved':
                return const _AccountStatusScreen(
                  icon: Icons.verified,
                  title: 'Washer account approved',
                  message:
                      'Your account is ready. Job offers will appear here in the next app phase.',
                );
              case 'rejected':
                return const _AccountStatusScreen(
                  icon: Icons.info_outline,
                  title: 'Application not approved',
                  message: 'Please contact the business for next steps.',
                );
              default:
                return const _AccountStatusScreen(
                  icon: Icons.block,
                  title: 'Washer access removed',
                  message:
                      'Please contact the business if you think this is a mistake.',
                );
            }
          },
        );
      },
    );
  }
}

class _AccountStatusScreen extends StatelessWidget {
  const _AccountStatusScreen({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(WashSpace.lg),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 48, color: WashColors.brand),
              const SizedBox(height: WashSpace.md),
              Text(title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: WashSpace.sm),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: WashSpace.lg),
              OutlinedButton(
                onPressed: () async => client.auth.signOut(),
                child: const Text('Sign out'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _WasherRegistrationScreen extends StatefulWidget {
  const _WasherRegistrationScreen(
      {this.initialName = '', this.initialSocietyId});
  final String initialName;
  final String? initialSocietyId;

  @override
  State<_WasherRegistrationScreen> createState() =>
      _WasherRegistrationScreenState();
}

class _WasherRegistrationScreenState extends State<_WasherRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _area = TextEditingController();
  final _picker = ImagePicker();
  late final Future<List<Map<String, dynamic>>> _societies;
  XFile? _avatar;
  XFile? _identity;
  String? _societyId;
  final Set<int> _days = {1, 2, 3, 4, 5, 6};
  TimeOfDay _start = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 14, minute: 0);
  String? _error;
  bool _busy = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _name.text = widget.initialName;
    _societyId = widget.initialSocietyId;
    _societies = Supabase.instance.client
        .from('societies')
        .select('id, name, city')
        .eq('active', true)
        .order('name')
        .then((rows) => List<Map<String, dynamic>>.from(rows));
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _takePhoto({required bool identity}) async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (image != null && mounted) {
        setState(() {
          if (identity) {
            _identity = image;
          } else {
            _avatar = image;
          }
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the camera. Please try again.');
      }
    }
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _chooseTime({required bool start}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (selected != null && mounted) {
      setState(() {
        if (start) {
          _start = selected;
        } else {
          _end = selected;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_avatar == null || _identity == null) {
      setState(
          () => _error = 'Take both your profile photo and ID document photo.');
      return;
    }
    if (_societyId == null ||
        _days.isEmpty ||
        (_start.hour * 60 + _start.minute) >= (_end.hour * 60 + _end.minute)) {
      setState(() =>
          _error = 'Choose your society, working days and a valid time range.');
      return;
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      const imageOptions = FileOptions(contentType: 'image/jpeg', upsert: true);
      const identityOptions =
          FileOptions(contentType: 'image/jpeg', upsert: true);
      final avatarPath = '${user.id}/avatar.jpg';
      final identityPath = '${user.id}/identity.jpg';
      await client.storage.from('avatars').uploadBinary(
            avatarPath,
            await _avatar!.readAsBytes(),
            fileOptions: imageOptions,
          );
      await client.storage.from('washer-ids').uploadBinary(
            identityPath,
            await _identity!.readAsBytes(),
            fileOptions: identityOptions,
          );
      await client.from('profiles').update({
        'full_name': _name.text.trim(),
        'avatar_path': avatarPath,
        'society_id': _societyId,
      }).eq('id', user.id);
      await client.from('washers').insert({
        'profile_id': user.id,
        'society_id': _societyId,
        'status': 'pending',
        'area': _area.text.trim(),
        'daily_cap': 0,
        'shift_hours': <Map<String, dynamic>>[],
        'requested_shift_hours': [
          {
            'days': (_days.toList()..sort()),
            'start': _formatTime(_start),
            'end': _formatTime(_end),
          },
        ],
      });
      if (mounted) setState(() => _submitted = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not submit your registration. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return const _AccountStatusScreen(
        icon: Icons.hourglass_top,
        title: 'Waiting for approval',
        message:
            'The business is reviewing your registration. You will not receive jobs until it is approved.',
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Washer registration')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _societies,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(WashSpace.lg),
              child:
                  Text('No active society is available for registration yet.'),
            ));
          }
          final societies = snapshot.data!;
          final selectedSociety =
              societies.any((row) => row['id'] == _societyId)
                  ? _societyId
                  : (societies.length == 1
                      ? societies.first['id'] as String
                      : null);
          _societyId ??= selectedSociety;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(WashSpace.lg),
              children: [
                Text('Join our washer team',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: WashSpace.sm),
                const Text(
                    'Share your details. The business will review your profile and ID before you receive work.'),
                const SizedBox(height: WashSpace.lg),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'Enter your full name.'
                      : null,
                ),
                const SizedBox(height: WashSpace.md),
                DropdownButtonFormField<String>(
                  initialValue: selectedSociety,
                  decoration: const InputDecoration(labelText: 'Society'),
                  items: societies
                      .map((row) => DropdownMenuItem<String>(
                            value: row['id'] as String,
                            child: Text('${row['name']} · ${row['city']}'),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _societyId = value),
                ),
                const SizedBox(height: WashSpace.md),
                TextFormField(
                  controller: _area,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(labelText: 'Area you can work in'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your working area.'
                      : null,
                ),
                const SizedBox(height: WashSpace.lg),
                _CaptureField(
                  title: 'Profile photo',
                  description: 'Take a clear photo of yourself.',
                  image: _avatar,
                  onCapture: () => _takePhoto(identity: false),
                ),
                const SizedBox(height: WashSpace.md),
                _CaptureField(
                  title: 'Identity document',
                  description:
                      'Take a clear photo of the document for business verification.',
                  image: _identity,
                  onCapture: () => _takePhoto(identity: true),
                ),
                const SizedBox(height: WashSpace.lg),
                Text('Preferred working days',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: WashSpace.sm),
                Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: List.generate(7, (index) {
                      const labels = [
                        'Sun',
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat'
                      ];
                      final day = index;
                      return FilterChip(
                        label: Text(labels[index]),
                        selected: _days.contains(day),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _days.add(day);
                          } else {
                            _days.remove(day);
                          }
                        }),
                      );
                    })),
                const SizedBox(height: WashSpace.sm),
                Row(children: [
                  Expanded(
                      child: OutlinedButton.icon(
                    onPressed: () => _chooseTime(start: true),
                    icon: const Icon(Icons.schedule),
                    label: Text('From ${_start.format(context)}'),
                  )),
                  const SizedBox(width: WashSpace.sm),
                  Expanded(
                      child: OutlinedButton.icon(
                    onPressed: () => _chooseTime(start: false),
                    icon: const Icon(Icons.schedule),
                    label: Text('Until ${_end.format(context)}'),
                  )),
                ]),
                const SizedBox(height: WashSpace.md),
                const Text(
                    'These are your preferred hours. The business sets your approved shifts and daily job cap.'),
                if (_error != null) ...[
                  const SizedBox(height: WashSpace.md),
                  Text(_error!,
                      style: const TextStyle(color: WashColors.danger)),
                ],
                const SizedBox(height: WashSpace.lg),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_busy ? 'Submitting…' : 'Submit for review'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CaptureField extends StatelessWidget {
  const _CaptureField({
    required this.title,
    required this.description,
    required this.image,
    required this.onCapture,
  });
  final String title;
  final String description;
  final XFile? image;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(WashSpace.md),
          child: Row(children: [
            if (image == null)
              const Icon(Icons.photo_camera_outlined,
                  size: 38, color: WashColors.brand)
            else
              FutureBuilder(
                future: image!.readAsBytes(),
                builder: (context, snapshot) => snapshot.hasData
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(WashRadius.control),
                        child: Image.memory(snapshot.data!,
                            width: 52, height: 52, fit: BoxFit.cover),
                      )
                    : const SizedBox.square(
                        dimension: 52, child: CircularProgressIndicator()),
              ),
            const SizedBox(width: WashSpace.md),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(description),
                ])),
            IconButton(
              onPressed: onCapture,
              tooltip: image == null ? 'Open camera' : 'Retake photo',
              icon: Icon(image == null ? Icons.camera_alt : Icons.refresh),
            ),
          ]),
        ),
      );
}
