import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';

// --- CYBERPUNK THEME COLORS ---
const Color cyberpunkBackground = Color(0xFF0A0A1A); // Dark, deep blue
const Color cyberpunkPrimary = Color(0xFF00FFFF); // Bright Cyan/Aqua
const Color cyberpunkAccent = Color(0xFFF8E71C); // Neon Yellow
const Color cyberpunkError = Color(0xFFFF003C); // Aggressive Red
const Color cyberpunkMuted = Color(0xFFCCCCCC); // Off-white/light grey

// A "netrunner-style" startup screen that appears before the terminal.
class HackerStartupScreen extends StatefulWidget {
  const HackerStartupScreen({Key? key}) : super(key: key);

  @override
  _HackerStartupScreenState createState() => _HackerStartupScreenState();
}

class _HackerStartupScreenState extends State<HackerStartupScreen> {
  final List<String> _startupLines = [];
  final ScrollController _scrollController = ScrollController();

  // List of boot-up messages to display sequentially.
  static const List<String> _bootSequence = [
    'INITIALIZING PROJECT RACO TERM...',
    'MOUNTING USER AS SUPERUSER...',
    'DETECTING KERNEL IS...',
    'MENELPON ADMIN...',
    'LOGIN IN WITH USER CREDS.',
    'ACCESS GRANTED. WELCOME, USER.',
    'LOADING PROJECT RACO TERMINAL...',
  ];

  @override
  void initState() {
    super.initState();
    // Start the boot sequence animation when the widget is initialized.
    _startBootSequence();
  }

  /// Displays boot messages with random delays to simulate a startup process.
  Future<void> _startBootSequence() async {
    // Wait a moment before starting to ensure the screen is visible.
    await Future.delayed(const Duration(milliseconds: 500));

    for (final line in _bootSequence) {
      if (!mounted) return; // Exit if the widget is disposed.
      setState(() {
        _startupLines.add(line);
      });
      // Scroll to the bottom to keep the latest line visible.
      _scrollToBottom();
      // Wait for a variable amount of time before showing the next line.
      await Future.delayed(Duration(milliseconds: 200 + Random().nextInt(500)));
    }

    // A final pause before transitioning to the terminal.
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      // Replace this screen with the terminal page.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const TerminalPage()),
      );
    }
  }

  void _scrollToBottom() {
    // A short delay ensures the list has time to update before scrolling.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use a monospaced font for a classic terminal look.
    const textStyle = TextStyle(
      fontFamily: 'monospace',
      color: cyberpunkPrimary,
      fontSize: 14,
      shadows: [
        Shadow(blurRadius: 4.0, color: cyberpunkPrimary, offset: Offset(0, 0)),
      ],
    );

    return Scaffold(
      backgroundColor: cyberpunkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _startupLines.length + 1, // +1 for the blinking cursor
            itemBuilder: (context, index) {
              if (index < _startupLines.length) {
                return Text(_startupLines[index], style: textStyle);
              } else {
                // Simulate a blinking cursor at the end.
                return const BlinkingCursor(style: textStyle);
              }
            },
          ),
        ),
      ),
    );
  }
}

/// A simple widget to create a blinking cursor effect.
class BlinkingCursor extends StatefulWidget {
  final TextStyle style;
  const BlinkingCursor({Key? key, required this.style}) : super(key: key);

  @override
  _BlinkingCursorState createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Text('_', style: widget.style),
    );
  }
}

// The main terminal interface page.
class TerminalPage extends StatefulWidget {
  const TerminalPage({Key? key}) : super(key: key);

  @override
  _TerminalPageState createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<Widget> _outputLines = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Add a welcome message when the terminal opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _outputLines.add(
          const Text(
            'Project Raco Terminal [1.0]\n(c) 2025 Kanagawa Yamada. All rights reserved.\nType "help" for available commands.',
            style: TextStyle(
              fontFamily: 'monospace',
              color: cyberpunkMuted,
              fontSize: 12,
            ),
          ),
        );
      });
      // Ensure the input field is focused.
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Executes the entered command using root privileges.
  Future<void> _runCommand(String command) async {
    if (command.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      // Display the entered command in the output.
      _outputLines.add(_buildPrompt(command));
    });
    _inputController.clear();
    _scrollToBottom();

    // Handle internal commands.
    if (command.trim().toLowerCase() == 'clear') {
      setState(() {
        _outputLines.clear();
        _isProcessing = false;
      });
      return;
    }

    if (command.trim().toLowerCase() == 'exit') {
      Navigator.of(context).pop();
      return;
    }

    // Execute the command as a root shell process.
    try {
      final result = await Process.run('su', ['-c', command]);
      final output = (result.stdout as String).trim();
      final error = (result.stderr as String).trim();

      if (output.isNotEmpty) {
        _outputLines.add(_buildOutput(output));
      }
      if (error.isNotEmpty) {
        _outputLines.add(_buildError(error));
      }
      if (output.isEmpty && error.isEmpty) {
        // Add a blank line for commands with no output.
        _outputLines.add(const SizedBox(height: 12)); // Match font size
      }
    } catch (e) {
      _outputLines.add(_buildError('ERROR: Subroutine failed. $e'));
    }

    setState(() {
      _isProcessing = false;
    });
    _scrollToBottom();
    // Re-focus the input field after command execution.
    FocusScope.of(context).requestFocus(_focusNode);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Helper methods to build styled text widgets.
  Widget _buildPrompt(String command) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        children: [
          const TextSpan(
            text: 'netrunner@localhost:~> ',
            style: TextStyle(
              color: cyberpunkAccent,
              shadows: [Shadow(blurRadius: 3.0, color: cyberpunkAccent)],
            ),
          ),
          TextSpan(
            text: command,
            style: const TextStyle(color: cyberpunkMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildOutput(String text) {
    return SelectableText(
      text,
      style: const TextStyle(
        fontFamily: 'monospace',
        color: cyberpunkMuted,
        fontSize: 12,
      ),
    );
  }

  Widget _buildError(String text) {
    return SelectableText(
      text,
      style: const TextStyle(
        fontFamily: 'monospace',
        color: cyberpunkError,
        fontSize: 12,
        shadows: [Shadow(blurRadius: 3.0, color: cyberpunkError)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const inputStyle = TextStyle(
      fontFamily: 'monospace',
      color: cyberpunkMuted,
      fontSize: 12,
    );

    return Scaffold(
      backgroundColor: cyberpunkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // MODIFICATION: Added fontSize to make the title smaller.
        title: const Text(
          'PROJECT RACO SHELL',
          style: TextStyle(
            fontFamily: 'monospace',
            color: cyberpunkAccent,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: cyberpunkAccent.withOpacity(0.5),
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).requestFocus(_focusNode),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // Scrollable output area.
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _outputLines.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: _outputLines[index],
                      );
                    },
                  ),
                ),
                // Input field area.
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      const Text(
                        'netrunner@localhost:~>',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: cyberpunkAccent,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          focusNode: _focusNode,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: inputStyle,
                          cursorColor: cyberpunkAccent,
                          onSubmitted: _runCommand,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
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
