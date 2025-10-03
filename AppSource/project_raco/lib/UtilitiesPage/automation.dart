import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '/l10n/app_localizations.dart';
import 'utils.dart';

class AutomationPage extends StatefulWidget {
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double backgroundBlur;

  const AutomationPage({
    Key? key,
    required this.backgroundImagePath,
    required this.backgroundOpacity,
    required this.backgroundBlur,
  }) : super(key: key);

  @override
  _AutomationPageState createState() => _AutomationPageState();
}

class _AutomationPageState extends State<AutomationPage> {
  bool _isLoading = true;
  Map<String, bool>? _hamadaAiState;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<Map<String, bool>> _loadHamadaAiState() async {
    final results = await Future.wait([
      runRootCommandAndWait('pgrep -x HamadaAI'),
      runRootCommandAndWait('cat /data/adb/modules/ProjectRaco/service.sh'),
    ]);
    return {
      'enabled': results[0].exitCode == 0,
      'onBoot': results[1].stdout.toString().contains('HamadaAI'),
    };
  }

  Future<void> _loadData() async {
    final hamadaState = await _loadHamadaAiState();

    if (!mounted) return;
    setState(() {
      _hamadaAiState = hamadaState;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    final Widget pageContent = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(localization.automation_title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        children: [
          HamadaAiCard(
            initialHamadaAiEnabled: _hamadaAiState?['enabled'] ?? false,
            initialHamadaStartOnBoot: _hamadaAiState?['onBoot'] ?? false,
          ),
          const GameTxtCard(),
        ],
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Theme.of(context).colorScheme.background),
        if (widget.backgroundImagePath != null &&
            widget.backgroundImagePath!.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: widget.backgroundBlur,
              sigmaY: widget.backgroundBlur,
            ),
            child: Opacity(
              opacity: widget.backgroundOpacity,
              child: Image.file(
                File(widget.backgroundImagePath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: Colors.transparent);
                },
              ),
            ),
          ),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0),
              child: LinearProgressIndicator(),
            ),
          )
        else
          pageContent,
      ],
    );
  }
}

class HamadaAiCard extends StatefulWidget {
  final bool initialHamadaAiEnabled;
  final bool initialHamadaStartOnBoot;

  const HamadaAiCard({
    Key? key,
    required this.initialHamadaAiEnabled,
    required this.initialHamadaStartOnBoot,
  }) : super(key: key);
  @override
  _HamadaAiCardState createState() => _HamadaAiCardState();
}

class _HamadaAiCardState extends State<HamadaAiCard> {
  late bool _hamadaAiEnabled;
  late bool _hamadaStartOnBoot;
  bool _isTogglingProcess = false;
  bool _isTogglingBoot = false;

  final String _serviceFilePath = '/data/adb/modules/ProjectRaco/service.sh';
  final String _hamadaStartCommand = 'su -c /system/bin/HamadaAI';

  @override
  void initState() {
    super.initState();
    _hamadaAiEnabled = widget.initialHamadaAiEnabled;
    _hamadaStartOnBoot = widget.initialHamadaStartOnBoot;
  }

  Future<Map<String, bool>> _fetchCurrentState() async {
    if (!await checkRootAccess()) {
      return {'enabled': _hamadaAiEnabled, 'onBoot': _hamadaStartOnBoot};
    }
    final results = await Future.wait([
      runRootCommandAndWait('pgrep -x HamadaAI'),
      runRootCommandAndWait('cat $_serviceFilePath'),
    ]);
    return {
      'enabled': results[0].exitCode == 0,
      'onBoot': results[1].stdout.toString().contains('HamadaAI'),
    };
  }

  Future<void> _refreshState() async {
    final state = await _fetchCurrentState();
    if (mounted) {
      setState(() {
        _hamadaAiEnabled = state['enabled'] ?? false;
        _hamadaStartOnBoot = state['onBoot'] ?? false;
      });
    }
  }

  Future<void> _toggleHamadaAI(bool enable) async {
    if (!await checkRootAccess()) return;
    if (mounted) setState(() => _isTogglingProcess = true);
    try {
      if (enable) {
        await runRootCommandFireAndForget(_hamadaStartCommand);
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        await runRootCommandAndWait('killall HamadaAI');
      }
      await _refreshState();
    } finally {
      if (mounted) setState(() => _isTogglingProcess = false);
    }
  }

  Future<void> _setHamadaStartOnBoot(bool enable) async {
    if (!await checkRootAccess()) return;
    if (mounted) setState(() => _isTogglingBoot = true);
    try {
      String content = (await runRootCommandAndWait(
        'cat $_serviceFilePath',
      )).stdout.toString();
      List<String> lines = content.replaceAll('\r\n', '\n').split('\n');
      lines.removeWhere((line) => line.trim() == _hamadaStartCommand);

      while (lines.isNotEmpty && lines.last.trim().isEmpty) {
        lines.removeLast();
      }

      if (enable) {
        lines.add(_hamadaStartCommand);
      }

      String newContent = lines.join('\n');
      if (newContent.isNotEmpty && !newContent.endsWith('\n')) {
        newContent += '\n';
      }

      String base64Content = base64Encode(utf8.encode(newContent));
      final writeCmd =
          '''echo '$base64Content' | base64 -d > $_serviceFilePath''';
      final result = await runRootCommandAndWait(writeCmd);

      if (result.exitCode == 0) {
        if (mounted) setState(() => _hamadaStartOnBoot = enable);
      } else {
        throw Exception('Failed to write to service file');
      }
    } catch (e) {
      // SnackBar removed from here
      if (mounted) {
        await _refreshState();
      }
    } finally {
      if (mounted) setState(() => _isTogglingBoot = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isBusy = _isTogglingProcess || _isTogglingBoot;

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localization.hamada_ai,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.hamada_ai_description,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(localization.hamada_ai_toggle_title),
              value: _hamadaAiEnabled,
              onChanged: isBusy ? null : _toggleHamadaAI,
              secondary: _isTogglingProcess
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.smart_toy_outlined),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: Text(localization.hamada_ai_start_on_boot),
              value: _hamadaStartOnBoot,
              onChanged: isBusy ? null : _setHamadaStartOnBoot,
              secondary: _isTogglingBoot
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.power_settings_new),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class GameTxtCard extends StatefulWidget {
  const GameTxtCard({Key? key}) : super(key: key);
  @override
  _GameTxtCardState createState() => _GameTxtCardState();
}

class _GameTxtCardState extends State<GameTxtCard> {
  // State variables to manage the UI and process
  bool _isBusy = false;
  bool _isEditing = false;
  String? _tempFilePath;

  // File paths
  static const String _originalFilePath = '/data/ProjectRaco/game.txt';
  static const String _tempFileName = 'game.txt';

  @override
  void initState() {
    super.initState();
    _checkForExistingTempFile();
  }

  /// Checks if a temp file was left over from a previous session.
  Future<void> _checkForExistingTempFile() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final tempFile = File('${cacheDir.path}/$_tempFileName');
      if (await tempFile.exists()) {
        if (!mounted) return;
        setState(() {
          _isEditing = true;
          _tempFilePath = tempFile.path;
        });
      }
    } catch (e) {
      // Handle potential errors finding the path
    }
  }

  /// Step 1: Copies game.txt to a temp location and opens it.
  Future<void> _startEditing() async {
    if (!await checkRootAccess()) {
      // SnackBar removed from here
      return;
    }
    setState(() => _isBusy = true);

    try {
      // Read original file using root
      final result = await runRootCommandAndWait('cat $_originalFilePath');
      if (result.exitCode != 0) {
        throw Exception('Failed to read original file: ${result.stderr}');
      }
      final originalContent = result.stdout.toString();

      // Create a temporary copy in the app's cache directory
      final cacheDir = await getApplicationCacheDirectory();
      final tempFile = File('${cacheDir.path}/$_tempFileName');
      await tempFile.writeAsString(originalContent);
      _tempFilePath = tempFile.path;

      // Use open_file to launch an editor for the temp file
      final openResult = await OpenFile.open(_tempFilePath!);
      if (openResult.type != ResultType.done) {
        throw Exception('Could not find an app to open the file.');
      }

      if (!mounted) return;
      setState(() => _isEditing = true);
      // SnackBar removed from here
    } catch (e) {
      // SnackBar removed from here
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Step 2: Syncs changes from the temp file back to the original.
  Future<void> _syncAndFinishEditing() async {
    if (_tempFilePath == null || !await checkRootAccess()) {
      // SnackBar removed from here
      return;
    }
    setState(() => _isBusy = true);

    try {
      // Read the modified content from our temp file
      final tempFile = File(_tempFilePath!);
      if (!await tempFile.exists()) {
        throw Exception('Temporary file not found. Please start again.');
      }
      final newContent = await tempFile.readAsString();

      // Use Base64 to safely write the content back with root
      String base64Content = base64Encode(utf8.encode(newContent));
      final writeCmd = "echo '$base64Content' | base64 -d > $_originalFilePath";
      final result = await runRootCommandAndWait(writeCmd);

      if (result.exitCode != 0) {
        throw Exception('Failed to write to original file: ${result.stderr}');
      }

      // Clean up the temporary file
      await tempFile.delete();

      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _tempFilePath = null;
      });
      // SnackBar removed from here
    } catch (e) {
      // SnackBar removed from here
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Determine button state based on whether we're editing
    final bool isActionSync = _isEditing;
    final String buttonText = isActionSync
        ? 'Sync Changes' // Consider adding to your l10n files
        : localization.edit_game_txt_title;
    final IconData buttonIcon = isActionSync ? Icons.sync : Icons.edit_note;
    final VoidCallback? onPressedAction = _isBusy
        ? null
        : (isActionSync ? _syncAndFinishEditing : _startEditing);

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localization.edit_game_txt_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.game_txt_hint,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPressedAction,
                icon: _isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(buttonIcon),
                label: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
