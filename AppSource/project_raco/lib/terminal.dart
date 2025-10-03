import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';

// A "hacker-style" startup screen that appears before the terminal.
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
    'Initializing Project Raco kernel v3.1.4...',
    'Mounting /dev/root on /...',
    'Scanning for hardware...',
    'Bypassing main security protocols...',
    'Establishing secure connection to mainframe...',
    'Accessing neural network core...',
    'DECRYPTION SUCCESSFUL.',
    'ACCESS GRANTED.',
    'Loading terminal interface...',
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
      color: Colors.greenAccent,
      fontSize: 16,
    );

    return Scaffold(
      backgroundColor: Colors.black,
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
            'Project Raco Terminal. Type "help" for a list of commands.',
            style: TextStyle(
              fontFamily: 'monospace',
              color: Colors.white,
              fontSize: 14,
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
        _outputLines.add(const SizedBox(height: 14));
      }
    } catch (e) {
      _outputLines.add(_buildError('Error executing command: $e'));
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
        style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
        children: [
          const TextSpan(
            text: 'root@raco:~# ',
            style: TextStyle(color: Colors.greenAccent),
          ),
          TextSpan(
            text: command,
            style: const TextStyle(color: Colors.white),
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
        color: Colors.white70,
        fontSize: 14,
      ),
    );
  }

  Widget _buildError(String text) {
    return SelectableText(
      text,
      style: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.redAccent,
        fontSize: 14,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const inputStyle = TextStyle(
      fontFamily: 'monospace',
      color: Colors.white,
      fontSize: 14,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // A dark, terminal-like color.
      appBar: AppBar(
        backgroundColor: Colors.black26,
        title: const Text('Terminal'),
        elevation: 0,
      ),
      // MODIFICATION: Wrapped the body with SafeArea.
      // This ensures the content avoids system UI like the navigation bar.
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
                        'root@raco:~#',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.greenAccent,
                          fontSize: 14,
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
                          cursorColor: Colors.greenAccent,
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
