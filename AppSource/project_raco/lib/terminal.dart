import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hacker-style startup screen with typing animation
class HackerStartupScreen extends StatefulWidget {
  const HackerStartupScreen({Key? key}) : super(key: key);

  @override
  State<HackerStartupScreen> createState() => _HackerStartupScreenState();
}

class _HackerStartupScreenState extends State<HackerStartupScreen> {
  final List<String> _startupLines = [
    '> Initializing secure connection...',
    '> Loading kernel modules...',
    '> Mounting system partitions...',
    '> Establishing root privileges...',
    '> Starting terminal shell...',
    '> Ready.',
  ];

  final List<String> _displayedLines = [];
  int _currentLineIndex = 0;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() async {
    for (int i = 0; i < _startupLines.length; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        _displayedLines.add(_startupLines[i]);
        _currentLineIndex = i;
      });
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _isComplete = true;
    });

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const TerminalPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Container(
        color: colorScheme.surface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.terminal, color: colorScheme.primary, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      'PROJECT RACO TERMINAL',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: ListView.builder(
                    itemCount: _displayedLines.length,
                    itemBuilder: (context, index) {
                      final isLast = index == _displayedLines.length - 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Text(
                              _displayedLines[index],
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (isLast && !_isComplete)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                width: 8,
                                height: 16,
                                color: colorScheme.primary,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Main Terminal Page
class TerminalPage extends StatefulWidget {
  const TerminalPage({Key? key}) : super(key: key);

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<TerminalLine> _lines = [];
  bool _isExecuting = false;
  List<String> _commandHistory = [];
  int _historyIndex = -1;
  String _currentInput = '';

  @override
  void initState() {
    super.initState();
    _lines.add(
      TerminalLine(
        text: 'Project Raco Terminal v1.0',
        isCommand: false,
        isError: false,
      ),
    );
    _lines.add(
      TerminalLine(
        text: 'Type "help" for available commands\n',
        isCommand: false,
        isError: false,
      ),
    );

    // Auto-focus the input field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _executeCommand(String command) async {
    if (command.trim().isEmpty) return;

    setState(() {
      _lines.add(
        TerminalLine(text: '\$ $command', isCommand: true, isError: false),
      );
      _isExecuting = true;
    });

    _commandHistory.insert(0, command);
    _historyIndex = -1;
    _scrollToBottom();

    final trimmedCommand = command.trim();
    final parts = trimmedCommand.split(' ');
    final baseCommand = parts[0].toLowerCase();

    await Future.delayed(const Duration(milliseconds: 100));

    switch (baseCommand) {
      case 'help':
        _addOutput(_getHelpText());
        break;
      case 'clear':
        setState(() {
          _lines.clear();
        });
        break;
      case 'echo':
        if (parts.length > 1) {
          _addOutput(parts.sublist(1).join(' '));
        }
        break;
      case 'date':
        _addOutput(DateTime.now().toString());
        break;
      case 'whoami':
        _addOutput('root');
        break;
      case 'pwd':
        _addOutput('/data/adb/modules/ProjectRaco');
        break;
      case 'uname':
        final args = parts.length > 1 ? parts[1] : '';
        if (args == '-a') {
          _addOutput('Linux localhost ${Platform.version}');
        } else {
          _addOutput('Linux');
        }
        break;
      case 'exit':
      case 'quit':
        Navigator.pop(context);
        return;
      default:
        // Execute actual shell command with root
        await _executeShellCommand(trimmedCommand);
    }

    setState(() {
      _isExecuting = false;
    });
    _scrollToBottom();
  }

  Future<void> _executeShellCommand(String command) async {
    try {
      final result = await Process.run('su', ['-c', command]);

      final stdout = (result.stdout as String).trim();
      final stderr = (result.stderr as String).trim();

      if (stdout.isNotEmpty) {
        _addOutput(stdout);
      }
      if (stderr.isNotEmpty) {
        _addOutput(stderr, isError: true);
      }
      if (stdout.isEmpty && stderr.isEmpty && result.exitCode != 0) {
        _addOutput(
          'Command exited with code ${result.exitCode}',
          isError: true,
        );
      }
    } catch (e) {
      _addOutput('Error: $e', isError: true);
    }
  }

  void _addOutput(String text, {bool isError = false}) {
    setState(() {
      _lines.add(TerminalLine(text: text, isCommand: false, isError: isError));
    });
  }

  String _getHelpText() {
    return '''Available Commands:
  help      - Show this help message
  clear     - Clear the terminal screen
  echo      - Display a line of text
  date      - Display current date and time
  whoami    - Display current user
  pwd       - Print working directory
  uname     - Print system information
  exit/quit - Exit terminal

You can also execute any shell command with root privileges.''';
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Navigate up in history
        if (_commandHistory.isNotEmpty &&
            _historyIndex < _commandHistory.length - 1) {
          if (_historyIndex == -1) {
            _currentInput = _inputController.text;
          }
          setState(() {
            _historyIndex++;
            _inputController.text = _commandHistory[_historyIndex];
            _inputController.selection = TextSelection.fromPosition(
              TextPosition(offset: _inputController.text.length),
            );
          });
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        // Navigate down in history
        if (_historyIndex > -1) {
          setState(() {
            _historyIndex--;
            if (_historyIndex == -1) {
              _inputController.text = _currentInput;
            } else {
              _inputController.text = _commandHistory[_historyIndex];
            }
            _inputController.selection = TextSelection.fromPosition(
              TextPosition(offset: _inputController.text.length),
            );
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.terminal, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text('Terminal', style: TextStyle(color: colorScheme.onSurface)),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: colorScheme.surface,
                padding: const EdgeInsets.all(16.0),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _lines.length,
                  itemBuilder: (context, index) {
                    final line = _lines[index];
                    return SelectableText(
                      line.text,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: line.isError
                            ? colorScheme.error
                            : line.isCommand
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontWeight: line.isCommand
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outline.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '\$ ',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: _handleKeyEvent,
                      child: TextField(
                        controller: _inputController,
                        focusNode: _focusNode,
                        enabled: !_isExecuting,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: _isExecuting
                              ? 'Executing...'
                              : 'Enter command',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (value) {
                          if (!_isExecuting) {
                            _executeCommand(value);
                            _inputController.clear();
                            _focusNode.requestFocus();
                          }
                        },
                      ),
                    ),
                  ),
                  if (_isExecuting)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.send, color: colorScheme.primary),
                      onPressed: () {
                        if (_inputController.text.isNotEmpty) {
                          _executeCommand(_inputController.text);
                          _inputController.clear();
                          _focusNode.requestFocus();
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Model class for terminal lines
class TerminalLine {
  final String text;
  final bool isCommand;
  final bool isError;

  TerminalLine({
    required this.text,
    required this.isCommand,
    required this.isError,
  });
}
