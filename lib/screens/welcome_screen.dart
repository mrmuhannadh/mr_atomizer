import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'connect_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _Info {
  final IconData icon;
  final String title, body;
  const _Info(this.icon, this.title, this.body);
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _Info(Icons.timer_outlined, 'Never forget to log time',
        'Jira Notifier checks your worklogs on weekdays and nudges you '
            'when you are short of your daily hours.'),
    _Info(Icons.alarm, 'Reminders on your schedule',
        'Choose the reminder time, the days, and the minimum hours. '
            'Change them any time in Settings.'),
    _Info(Icons.lock_outline, 'Your token stays on your device',
        'Your API token is stored in your device\'s secure storage and is '
            'only ever sent to your own Jira site.'),
  ];

  bool get _isLast => _page == _pages.length - 1;

  Future<void> _finish() async {
    await StorageService.setOnboarded();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ConnectScreen()));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: _isLast ? null : _finish,
                    child: Text(_isLast ? '' : 'Skip')),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) {
                    final p = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                                radius: 56,
                                backgroundColor: cs.primaryContainer,
                                child: Icon(p.icon,
                                    size: 56, color: cs.onPrimaryContainer)),
                            const SizedBox(height: 32),
                            Text(p.title,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Text(p.body,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge),
                          ]),
                    );
                  },
                ),
              ),
              // page dots
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.all(4),
                    height: 8,
                    width: i == _page ? 24 : 8,
                    decoration: BoxDecoration(
                        color: i == _page ? cs.primary : cs.outlineVariant,
                        borderRadius: BorderRadius.circular(4)),
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLast
                        ? _finish
                        : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut),
                    child: Text(_isLast ? 'Get started' : 'Next'),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}