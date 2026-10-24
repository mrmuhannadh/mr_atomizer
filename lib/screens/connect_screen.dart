import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/settings.dart';
import '../services/jira_service.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  static const _tokenPage =
      'https://id.atlassian.com/manage-profile/security/api-tokens';

  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _email = TextEditingController();
  final _token = TextEditingController();
  bool _loading = false, _hide = true;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _email.dispose();
    _token.dispose();
    super.dispose();
  }

  /// Accepts "mycompany", "mycompany.atlassian.net" or a full/long URL
  /// and returns just "https://host".
  String _normalizeUrl(String input) {
    var u = input.trim();
    if (!u.contains('.') && !u.contains('/') && !u.contains(':')) {
      u = '$u.atlassian.net';
    }
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    final uri = Uri.parse(u);
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  String? _validateUrl(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter your Jira site';
    try {
      final host = Uri.parse(_normalizeUrl(v)).host;
      if (host.isEmpty || !host.contains('.')) return 'That does not look like a valid site';
    } catch (_) {
      return 'That does not look like a valid site';
    }
    return null;
  }

  String? _validateEmail(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Enter your Atlassian email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Enter a valid email';
    return null;
  }

  String? _validateToken(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Paste your API token' : null;

  Future<void> _pasteToken() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() => _token.text = data!.text!.trim());
    }
  }

  Future<void> _openTokenPage() async {
    try {
      final ok = await launchUrl(Uri.parse(_tokenPage),
          mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}
    await Clipboard.setData(const ClipboardData(text: _tokenPage));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not open the browser. Link copied instead.')));
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = _normalizeUrl(_url.text);
      final email = _email.text.trim();
      final token = _token.text.trim();
      final me = await JiraService(url, email, token).myself();

      await StorageService.saveCredentials(
          Credentials(url, email, token, me['accountId'] as String));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on DioException catch (e) {
      debugPrint(
          'Jira error: ${e.type} | ${e.response?.statusCode} | ${e.message} | ${e.error}');
      final code = e.response?.statusCode;
      String msg;
      if (code == 401 || code == 403) {
        msg = 'Jira rejected the email or token. Check both and try again.';
      } else if (code == 404) {
        msg = 'Jira site not found. Check the site name.';
      } else if (code != null) {
        msg = 'Jira returned an error ($code).';
      } else {
        msg = 'Could not reach Jira. Check the site name and your internet connection.';
      }
      setState(() => _error = msg);
    } catch (e) {
      debugPrint('Connect error: $e');
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _step(int n, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(radius: 11, child: Text('$n', style: const TextStyle(fontSize: 12))),
      const SizedBox(width: 10),
      Expanded(child: Text(text)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to Jira')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(padding: const EdgeInsets.all(24), children: [
              // ----- Header -----
              Center(
                child: CircleAvatar(
                    radius: 36,
                    backgroundColor: cs.primaryContainer,
                    child: Icon(Icons.link, size: 36, color: cs.onPrimaryContainer)),
              ),
              const SizedBox(height: 16),
              Text('Connect your Jira account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'We need read access to your worklogs to know when you are short on hours.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    validator: _validateUrl,
                    decoration: const InputDecoration(
                        labelText: 'Jira site',
                        hintText: 'yourcompany.atlassian.net',
                        helperText: 'Just the site name or address is enough',
                        prefixIcon: Icon(Icons.language),
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    validator: _validateEmail,
                    decoration: const InputDecoration(
                        labelText: 'Atlassian email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _token,
                    obscureText: _hide,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _loading ? null : _connect(),
                    validator: _validateToken,
                    decoration: InputDecoration(
                      labelText: 'API token',
                      prefixIcon: const Icon(Icons.key),
                      border: const OutlineInputBorder(),
                      suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            tooltip: 'Paste',
                            icon: const Icon(Icons.content_paste),
                            onPressed: _pasteToken),
                        IconButton(
                            tooltip: _hide ? 'Show' : 'Hide',
                            icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _hide = !_hide)),
                      ]),
                    ),
                  ),
                ]),
              ),

              // ----- Error banner -----
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.error_outline, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: TextStyle(color: cs.onErrorContainer))),
                  ]),
                ),

              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _connect,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: _loading
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Connect'),
              ),

              // ----- Privacy note -----
              const SizedBox(height: 16)
            ]),
          ),
        ),
      ),
    );
  }
}