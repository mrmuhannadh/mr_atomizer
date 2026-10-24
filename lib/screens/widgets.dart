import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/planner.dart';
import '../services/jira_service.dart';
import '../services/storage_service.dart';

Widget centered(Widget child) => Center(
    child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640), child: child));

/// Numeric hours input. Give it a stable key so it keeps its own text.
class HoursField extends StatelessWidget {
  final double value;
  final String label;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const HoursField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Hours',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        value == value.roundToDouble() ? '${value.toInt()}' : '$value';
    return SizedBox(
      width: 100,
      child: TextFormField(
        initialValue: initial,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: 'h',
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) => onChanged(double.tryParse(v.replaceAll(',', '.')) ?? 0),
      ),
    );
  }
}

/// Bottom sheet to search Jira and pick one or more tasks.
Future<List<JiraIssue>?> showIssuePicker(BuildContext context,
    {required Set<String> exclude}) {
  return showModalBottomSheet<List<JiraIssue>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
        heightFactor: 0.92, child: _IssuePicker(exclude: exclude)),
  );
}

class _IssuePicker extends StatefulWidget {
  final Set<String> exclude;
  const _IssuePicker({required this.exclude});
  @override
  State<_IssuePicker> createState() => _IssuePickerState();
}

class _IssuePickerState extends State<_IssuePicker> {
  final _q = TextEditingController();
  final Map<String, JiraIssue> _selected = {};
  Timer? _debounce;
  JiraService? _jira;
  List<JiraIssue> _results = [];
  bool _loading = true;
  String? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = await StorageService.credentials();
    if (c == null) {
      setState(() {
        _loading = false;
        _error = 'Not connected to Jira.';
      });
      return;
    }
    _jira = JiraService(c.url, c.email, c.token);
    _search('');
  }

  Future<void> _search(String q) async {
    final my = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _jira!.searchIssues(q);
      if (!mounted || my != _seq) return;
      setState(() => _results = r);
    } catch (e) {
      if (!mounted || my != _seq) return;
      setState(() => _error = 'Could not search Jira. $e');
    } finally {
      if (mounted && my == _seq) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    if (_results.isEmpty) return const Center(child: Text('No tasks found.'));
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final it = _results[i];
        final already = widget.exclude.contains(it.key);
        return CheckboxListTile(
          value: already || _selected.containsKey(it.key),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: already
              ? null
              : (v) => setState(() {
                    if (v == true) {
                      _selected[it.key] = it;
                    } else {
                      _selected.remove(it.key);
                    }
                  }),
          title: Text('${it.key}  ${it.summary}',
              maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              '${it.status}  •  ${it.priority}${already ? '  •  already added' : ''}'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(children: [
            Expanded(
                child: Text('Add tasks',
                    style: Theme.of(context).textTheme.titleLarge)),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _q,
            autocorrect: false,
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () => _search(v));
            },
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search by ID (ABC-123) or text',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
                _q.text.trim().isEmpty
                    ? 'Your To Do and In Progress tasks, highest priority first'
                    : 'Search results',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        Expanded(child: _body()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selected.values.toList()),
                child: Text(_selected.isEmpty
                    ? 'Select tasks'
                    : 'Add ${_selected.length} task${_selected.length == 1 ? '' : 's'}'),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// After opening Outlook the app can't know if the email was really sent.
Future<bool> confirmSentDialog(BuildContext context, String plainText) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('Did you send it?'),
      content: const Text(
          'Outlook should have opened with the email filled in. Review it, '
          'press Send there, then confirm here so reminders and status stay correct.'),
      actions: [
        TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: plainText)),
            child: const Text('Copy text')),
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, sent')),
      ],
    ),
  );
  return r == true;
}
