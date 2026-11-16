import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    const useEmulators = bool.fromEnvironment(
      'USE_EMULATORS',
      defaultValue: false,
    );

    const emulatorHost = String.fromEnvironment(
      'EMULATOR_HOST',
      defaultValue: '127.0.0.1',
    );

       if (useEmulators) {
      await FirebaseAuth.instance.useAuthEmulator(
        emulatorHost,
        9099,
        automaticHostMapping: false,
      );

      FirebaseFirestore.instance.useFirestoreEmulator(
        emulatorHost,
        8080,
        automaticHostMapping: false,
      );

      FirebaseFunctions.instanceFor(region: 'us-central1')
          .useFunctionsEmulator(
        emulatorHost,
        5001,
        automaticHostMapping: false,
      );
    }

    runApp(const MyApp());
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Firebase could not start.\n'
                'Check the emulator connection and restart the app.\n\n'
                '$error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cloud Quest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authChanges = FirebaseAuth.instance
      .authStateChanges();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authChanges,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Could not check your session. Restart the app.'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const SignInScreen();
        }

        return ChallengeScreen(key: ValueKey(user.uid), user: user);
      },
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _registering = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final auth = FirebaseAuth.instance;

      if (_registering) {
        await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = switch (error.code) {
          'email-already-in-use' =>
            'This email already has an account. Try signing in.',
          'weak-password' => 'Use a stronger password.',
          'invalid-email' => 'Enter a valid email address.',
          'invalid-credential' ||
          'wrong-password' ||
          'user-not-found' => 'The email or password is incorrect.',
          'network-request-failed' =>
            'Could not connect. Check that the emulators are running.',
          'too-many-requests' => 'Too many attempts. Please try again later.',
          _ => 'Authentication failed (${error.code}). Please try again.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not sign in. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Quest')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.explore, size: 72),
                  const SizedBox(height: 16),
                  Text(
                    _registering ? 'Create your account' : 'Welcome back',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to begin your daily quest.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(email)) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter your password.';
                      }
                      if (_registering && value.length < 6) {
                        return 'Use at least 6 characters.';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy
                          ? 'Please wait...'
                          : _registering
                          ? 'Create account'
                          : 'Sign in',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() {
                              _registering = !_registering;
                              _error = null;
                            });
                          },
                    child: Text(
                      _registering
                          ? 'Already registered? Sign in'
                          : 'New learner? Create an account',
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

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key, required this.user});

  final User user;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  final _question = TextEditingController();

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _challenge;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _progress;

  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  bool _completing = false;
  bool _asking = false;
  bool _signingOut = false;
  String? _reply;
  String? _coachError;

  bool get _busy => _completing || _asking || _signingOut;

  @override
  void initState() {
    super.initState();

    _challenge = FirebaseFirestore.instance.doc('challenges/today').snapshots();

    _progress = FirebaseFirestore.instance
        .doc('users/${widget.user.uid}/progress/today')
        .snapshots();
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _complete() async {
    if (_busy) return;

    FocusScope.of(context).unfocus();
    setState(() => _completing = true);

    try {
      final result = await _functions.httpsCallable('completeToday').call(
        <String, dynamic>{'challengeId': 'today'},
      );

      if (!mounted) return;

      final data = Map<String, dynamic>.from(result.data as Map);

      _showMessage(
        data['alreadyCompleted'] == true
            ? 'Already completed. Your reward has not increased.'
            : 'Quest complete! You earned 10 points and First Quest.',
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;

      _showMessage(
        'Could not confirm completion (${error.code}). '
        'You can retry safely.',
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not confirm completion. Please retry.');
    } finally {
      if (mounted) {
        setState(() => _completing = false);
      }
    }
  }

  Future<void> _askCoach() async {
    if (_busy) return;

    final question = _question.text.trim();

    if (question.isEmpty || question.length > 300) {
      setState(() {
        _coachError = 'Enter a question between 1 and 300 characters.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _asking = true;
      _reply = null;
      _coachError = null;
    });

    try {
      final result = await _functions.httpsCallable('askQuestCoach').call(
        <String, dynamic>{'question': question},
      );

      if (!mounted) return;

      final data = Map<String, dynamic>.from(result.data as Map);
      final reply = data['reply'];

      if (reply is! String || reply.trim().isEmpty) {
        throw const FormatException('Missing coach reply.');
      }

      setState(() => _reply = reply);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;

      setState(() {
        _coachError =
            'The coach is unavailable (${error.code}). Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _coachError = 'Could not load a coach reply. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _asking = false);
      }
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _signingOut = true);

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (mounted) {
        _showMessage('Could not sign out. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _signingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Quest'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _busy ? null : _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Signed in as ${widget.user.email ?? widget.user.uid}'),
          const SizedBox(height: 20),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _challenge,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Could not load the challenge. Check the connection.',
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!.data();
              final title = data?['title'];
              final prompt = data?['prompt'];

              if (title is! String ||
                  prompt is! String ||
                  title.trim().isEmpty ||
                  prompt.trim().isEmpty) {
                return const Text(
                  'Today’s challenge is missing or incomplete.',
                );
              }

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(prompt),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _busy ? null : _complete,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          _completing
                              ? 'Checking reward...'
                              : 'Complete challenge',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _progress,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Could not load your progress.');
              }

              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }

              final data = snapshot.data!.data();
              final completed = data?['completed'] == true;
              final points = data?['points'] ?? 0;
              final badge = data?['badgeId'] == 'first-quest'
                  ? 'First Quest'
                  : 'None yet';

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your progress',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Status: ${completed ? 'Completed' : 'Not completed'}',
                      ),
                      Text('Points: $points'),
                      Text('Badge: $badge'),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Quest Coach', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Ask for a hint. Only the Complete challenge button '
            'can request your reward.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _question,
            enabled: !_busy,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Ask the Quest Coach',
              border: OutlineInputBorder(),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _askCoach,
            icon: const Icon(Icons.lightbulb_outline),
            label: Text(_asking ? 'Thinking...' : 'Get hint'),
          ),
          if (_coachError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _coachError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_reply != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_reply!),
              ),
            ),
        ],
      ),
    );
  }
}
