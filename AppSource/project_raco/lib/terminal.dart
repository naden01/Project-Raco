import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// Cool hacker startup screen before terminal launches
class HackerStartupScreen extends StatefulWidget {
  const HackerStartupScreen({Key? key}) : super(key: key);

  @override
  State<HackerStartupScreen> createState() => _HackerStartupScreenState();
}

class _HackerStartupScreenState extends State<HackerStartupScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _bootMessages = [
    'INITIALIZING SECURE CONNECTION...',
    'BYPASSING FIREWALL...',
    'ESTABLISHING ROOT PRIVILEGES...',
    'LOADING TERMINAL INTERFACE...',
    'DECRYPTING KERNEL MODULES...',
    'MOUNTING SYSTEM PARTITIONS...',
    'READY.',
  ];

  int _currentMessageIndex = 0;
  late AnimationController _glitchController;

  @override
  void initState() {
    super.initState();
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat(reverse: true);

    _startBootSequence();
  }

  @override
  void dispose() {
    _glitchController.dispose();
    super.dispose();
  }

  void _startBootSequence() {
    Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_currentMessageIndex < _bootMessages.length) {
          _currentMessageIndex++;
        } else {
          timer.cancel();
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const TerminalPage()),
              );
            }
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.black, primaryColor.withOpacity(0.1), Colors.black],
          ),
        ),
        child: Stack(
          children: [
            // Scanline effect
            AnimatedBuilder(
              animation: _glitchController,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.05,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          primaryColor.withOpacity(0.3),
                          Colors.transparent,
                        ],
                        stops: [
                          _glitchController.value - 0.1,
                          _glitchController.value,
                          _glitchController.value + 0.1,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            // Content
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.terminal, size: 80, color: primaryColor),
                    const SizedBox(height: 32),
                    Text(
                      '[ PROJECT RACO ]',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        letterSpacing: 4,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TERMINAL ACCESS',
                      style: TextStyle(
                        fontSize: 14,
                        color: primaryColor.withOpacity(0.7),
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: _currentMessageIndex,
                        itemBuilder: (context, index) {
                          final isLast = index == _currentMessageIndex - 1;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Text(
                                  '> ',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _bootMessages[index],
                                    style: TextStyle(
                                      color: isLast
                                          ? primaryColor
                                          : primaryColor.withOpacity(0.5),
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (isLast)
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        primaryColor,
                                      ),
                                    ),
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
          ],
        ),
      ),
    );
  }
}

/// Main terminal page with xterm implementation
class TerminalPage extends StatefulWidget {
  const TerminalPage({Key? key}) : super(key: key);

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  late Terminal _terminal;
  late TerminalController _terminalController;
  Process? _shellProcess;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTerminal();
  }

  Future<void> _initializeTerminal() async {
    _terminal = Terminal(maxLines: 10000);

    _terminalController = TerminalController();

    // Welcome message
    _terminal.write('Project Raco Terminal\r\n');
    _terminal.write('Type "help" for available commands\r\n');
    _terminal.write('Type "exit" to close terminal\r\n\r\n');

    try {
      // Start shell process with root access
      _shellProcess = await Process.start('su', ['-c', 'sh'], runInShell: true);

      // Listen to stdout
      _shellProcess!.stdout.listen((data) {
        if (mounted) {
          _terminal.write(String.fromCharCodes(data));
        }
      });

      // Listen to stderr
      _shellProcess!.stderr.listen((data) {
        if (mounted) {
          _terminal.write(String.fromCharCodes(data));
        }
      });

      // Handle process exit
      _shellProcess!.exitCode.then((exitCode) {
        if (mounted) {
          _terminal.write('\r\nProcess exited with code $exitCode\r\n');
          _terminal.write('Press back button to exit terminal.\r\n');
        }
      });

      setState(() {
        _isInitialized = true;
      });

      // Write initial prompt
      _shellProcess!.stdin.writeln('export PS1="\$ "');
    } catch (e) {
      _terminal.write('Error starting shell: $e\r\n');
      _terminal.write('Running in limited mode.\r\n');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _handleInput(String input) {
    if (_shellProcess != null) {
      try {
        // Handle exit command
        if (input.trim() == 'exit') {
          _shellProcess!.stdin.writeln('exit');
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
          return;
        }

        // Send command to shell
        _shellProcess!.stdin.writeln(input);
      } catch (e) {
        _terminal.write('Error: $e\r\n');
      }
    }
  }

  @override
  void dispose() {
    _shellProcess?.kill();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Terminal'),
        backgroundColor: Colors.black,
        foregroundColor: colorScheme.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _shellProcess?.kill();
              setState(() {
                _isInitialized = false;
              });
              _initializeTerminal();
            },
            tooltip: 'Restart Terminal',
          ),
        ],
      ),
      body: _isInitialized
          ? SafeArea(
              child: TerminalView(
                _terminal,
                controller: _terminalController,
                autofocus: true,
                backgroundOpacity: 1.0,
                theme: TerminalTheme(
                  cursor: colorScheme.primary,
                  selection: colorScheme.primary.withOpacity(0.3),
                  foreground: colorScheme.primary,
                  background: Colors.black,
                  black: Colors.black,
                  red: Colors.red,
                  green: Colors.green,
                  yellow: Colors.yellow,
                  blue: Colors.blue,
                  magenta: Colors.purple,
                  cyan: Colors.cyan,
                  white: Colors.white,
                  brightBlack: Colors.grey,
                  brightRed: Colors.redAccent,
                  brightGreen: Colors.greenAccent,
                  brightYellow: Colors.yellowAccent,
                  brightBlue: Colors.blueAccent,
                  brightMagenta: Colors.purpleAccent,
                  brightCyan: Colors.cyanAccent,
                  brightWhite: Colors.white,
                  searchHitBackground: Colors.yellow.withOpacity(0.5),
                  searchHitBackgroundCurrent: Colors.orange.withOpacity(0.7),
                  searchHitForeground: Colors.black,
                ),
              ),
            )
          : Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            ),
    );
  }
}
