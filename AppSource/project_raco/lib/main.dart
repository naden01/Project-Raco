import 'package:flutter/material.dart';
import 'package:process_run/process_run.dart';
import 'dart:async';
import 'dart:io';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:url_launcher/url_launcher.dart';
import 'about_page.dart';
import 'utilities_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '/l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Manages reading and writing configuration settings using SharedPreferences.
/// The app will remember the last selected mode locally.
class ConfigManager {
  static const String _modeKey = 'current_mode';
  static const String _defaultMode = 'NONE';

  /// Reads the current mode from SharedPreferences.
  static Future<Map<String, String>> readConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String currentMode = prefs.getString(_modeKey) ?? _defaultMode;
      return {'current_mode': currentMode};
    } catch (e) {
      return {'current_mode': _defaultMode};
    }
  }

  /// Saves the current mode to SharedPreferences.
  static Future<void> saveMode(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, mode.toUpperCase());
    } catch (e) {
      // Error saving mode
    }
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;
  String? _backgroundImagePath;
  double _backgroundOpacity = 0.2;
  String? _bannerImagePath; // Added banner image path state

  static final _defaultLightColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.blue,
  );
  static final _defaultDarkColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.dark,
  );

  @override
  void initState() {
    super.initState();
    _loadAllPreferences();
  }

  Future<void> _loadAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final languageCode = prefs.getString('language_code') ?? 'en';
    final path = prefs.getString('background_image_path');
    final opacity = prefs.getDouble('background_opacity') ?? 0.2;
    final bannerPath = prefs.getString('banner_image_path'); // Load banner path

    setState(() {
      _locale = Locale(languageCode);
      _backgroundImagePath = path;
      _backgroundOpacity = opacity;
      _bannerImagePath = bannerPath; // Set banner path state
    });
  }

  Future<void> _updateLocale(Locale locale) async {
    if (!mounted) return;
    setState(() {
      _locale = locale;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme =
            lightDynamic?.harmonized() ?? _defaultLightColorScheme;
        ColorScheme darkColorScheme =
            darkDynamic?.harmonized() ?? _defaultDarkColorScheme;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: _locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    // UPDATED: Added a container for the default background color
                    Container(color: Theme.of(context).colorScheme.background),
                    if (_backgroundImagePath != null &&
                        _backgroundImagePath!.isNotEmpty)
                      Opacity(
                        opacity: _backgroundOpacity,
                        child: Image.file(
                          File(_backgroundImagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(color: Colors.transparent);
                          },
                        ),
                      ),
                    MainScreen(
                      onLocaleChange: _updateLocale,
                      onUtilitiesClosed: _loadAllPreferences,
                      bannerImagePath: _bannerImagePath, // Pass banner path
                    ),
                  ],
                ),
              );
            },
          ),
          theme: ThemeData(useMaterial3: true, colorScheme: lightColorScheme),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkColorScheme,
          ),
          themeMode: ThemeMode.system,
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final Function(Locale) onLocaleChange;
  final VoidCallback onUtilitiesClosed;
  final String? bannerImagePath; // Receive banner path

  MainScreen({
    required this.onLocaleChange,
    required this.onUtilitiesClosed,
    required this.bannerImagePath, // Updated constructor
  });

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  bool _hasRootAccess = false;
  bool _moduleInstalled = false;
  String _moduleVersion = 'Unknown';
  String _currentMode = 'NONE';
  String _selectedLanguage = 'EN';
  String _executingScript = '';
  bool _isLoading = true;
  bool _isHamadaAiRunning = false;
  Timer? _hamadaCheckTimer;
  bool _isContentVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hamadaCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _initializeState();
    } else if (state == AppLifecycleState.paused) {
      _hamadaCheckTimer?.cancel();
    }
  }

  void _startHamadaTimer() {
    _hamadaCheckTimer?.cancel();
    if (mounted) {
      _hamadaCheckTimer = Timer.periodic(Duration(seconds: 3), (timer) {
        if (mounted) {
          _checkHamadaProcessStatus();
        }
      });
    }
  }

  Future<void> _loadSelectedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final languageCode = prefs.getString('language_code') ?? 'en';
    const codeMap = {'en': 'EN', 'id': 'ID', 'ja': 'JP'};
    setState(() {
      _selectedLanguage = codeMap[languageCode] ?? 'EN';
    });
  }

  Future<void> _initializeState() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    await _loadSelectedLanguage();

    final rootGranted = await _checkRootAccess();
    if (rootGranted) {
      final config = await ConfigManager.readConfig();
      await _checkHamadaProcessStatus();
      await _checkModuleInstalled();
      if (_moduleInstalled) await _getModuleVersion();

      if (mounted) {
        setState(() {
          _currentMode = config['current_mode'] ?? 'NONE';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _moduleInstalled = false;
          _moduleVersion = 'Root Required';
          _currentMode = 'Root Required';
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isContentVisible = true;
      });
      _startHamadaTimer();
    }
  }

  Future<bool> _checkRootAccess() async {
    try {
      var result = await run('su', ['-c', 'id'], verbose: false);
      bool hasAccess = result.exitCode == 0;
      if (mounted) setState(() => _hasRootAccess = hasAccess);
      return hasAccess;
    } catch (e) {
      if (mounted) setState(() => _hasRootAccess = false);
      return false;
    }
  }

  Future<void> _checkHamadaProcessStatus() async {
    if (!_hasRootAccess) return;
    try {
      final result = await run('su', [
        '-c',
        'pgrep -x HamadaAI',
      ], verbose: false);
      bool isRunning = result.exitCode == 0;
      if (mounted && _isHamadaAiRunning != isRunning) {
        setState(() => _isHamadaAiRunning = isRunning);
      }
    } catch (e) {
      if (mounted && _isHamadaAiRunning) {
        setState(() => _isHamadaAiRunning = false);
      }
    }
  }

  Future<void> _checkModuleInstalled() async {
    if (!_hasRootAccess) return;
    try {
      var result = await run('su', [
        '-c',
        'test -d /data/adb/modules/ProjectRaco && echo "yes"',
      ], verbose: false);
      if (mounted) {
        setState(
          () => _moduleInstalled = result.stdout.toString().trim() == 'yes',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _moduleInstalled = false);
    }
  }

  Future<void> _getModuleVersion() async {
    if (!_hasRootAccess || !_moduleInstalled) return;
    try {
      var result = await run('su', [
        '-c',
        'grep "^version=" /data/adb/modules/ProjectRaco/module.prop',
      ], verbose: false);
      String line = result.stdout.toString().trim();
      String version = line.contains('=')
          ? line.split('=')[1].trim()
          : 'Unknown';
      if (mounted) {
        setState(
          () => _moduleVersion = version.isNotEmpty ? version : 'Unknown',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _moduleVersion = 'Error');
    }
  }

  Future<void> executeScript(String scriptArg, String modeKey) async {
    if (!_hasRootAccess ||
        !_moduleInstalled ||
        _executingScript.isNotEmpty ||
        _isHamadaAiRunning)
      return;

    String targetMode = (modeKey == 'CLEAR' || modeKey == 'COOLDOWN')
        ? 'NONE'
        : modeKey;

    if (mounted) {
      setState(() {
        _executingScript = scriptArg;
        _currentMode = targetMode;
      });
    }

    try {
      await ConfigManager.saveMode(targetMode);
      var result = await run('su', [
        '-c',
        'sh /data/adb/modules/ProjectRaco/Scripts/Raco.sh $scriptArg',
      ], verbose: false);

      if (result.exitCode != 0) {
        await _refreshStateFromConfig();
      }
    } catch (e) {
      await _refreshStateFromConfig();
    } finally {
      if (mounted) setState(() => _executingScript = '');
    }
  }

  Future<void> _refreshStateFromConfig() async {
    if (!_hasRootAccess) return;
    var config = await ConfigManager.readConfig();
    if (mounted) {
      setState(() {
        _currentMode = config['current_mode'] ?? 'NONE';
      });
    }
  }

  void _changeLanguage(String language) {
    if (language == _selectedLanguage) return;

    const localeMap = {'EN': 'en', 'ID': 'id', 'JP': 'ja'};
    String localeCode = localeMap[language.toUpperCase()] ?? 'en';
    widget.onLocaleChange(Locale(localeCode));

    if (mounted) setState(() => _selectedLanguage = language.toUpperCase());
  }

  Future<void> _launchURL(String url) async {
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
      }
    }
  }

  void _navigateToAboutPage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AboutPage(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _navigateToUtilitiesPage() async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            UtilitiesPage(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    _initializeState();
    widget.onUtilitiesClosed();
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: LinearProgressIndicator(),
                  ),
                )
              : AnimatedOpacity(
                  opacity: _isContentVisible ? 1.0 : 0.0,
                  duration: Duration(milliseconds: 500),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleHeader(colorScheme, localization),
                        SizedBox(height: 16),
                        _buildBannerAndStatus(localization),
                        SizedBox(height: 10),
                        _buildControlRow(
                          localization.power_save_desc,
                          '3',
                          localization.power_save,
                          Icons.battery_saver_outlined,
                          'POWER_SAVE',
                        ),
                        _buildControlRow(
                          localization.balanced_desc,
                          '2',
                          localization.balanced,
                          Icons.balance_outlined,
                          'BALANCED',
                        ),
                        _buildControlRow(
                          localization.performance_desc,
                          '1',
                          localization.performance,
                          Icons.speed_outlined,
                          'PERFORMANCE',
                        ),
                        _buildControlRow(
                          localization.gaming_desc,
                          '4',
                          localization.gaming_pro,
                          Icons.sports_esports_outlined,
                          'GAMING_PRO',
                        ),
                        _buildControlRow(
                          localization.cooldown_desc,
                          '5',
                          localization.cooldown,
                          Icons.ac_unit_outlined,
                          'COOLDOWN',
                        ),
                        _buildControlRow(
                          localization.clear_desc,
                          '6',
                          localization.clear,
                          Icons.clear_all_outlined,
                          'CLEAR',
                        ),
                        _buildUtilitiesCard(localization),
                        SizedBox(height: 10),
                        _buildLanguageSelector(localization),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTitleHeader(
    ColorScheme colorScheme,
    AppLocalizations localization,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _navigateToAboutPage,
                child: Text(
                  localization.app_title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              Text(
                localization.by,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: FaIcon(
                FontAwesomeIcons.telegram,
                color: colorScheme.primary,
              ),
              onPressed: () => _launchURL('https://t.me/KLAGen2'),
              tooltip: 'Telegram',
            ),
            IconButton(
              icon: FaIcon(FontAwesomeIcons.github, color: colorScheme.primary),
              onPressed: () => _launchURL(
                'https://github.com/LoggingNewMemory/Project-Raco',
              ),
              tooltip: 'GitHub',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBannerAndStatus(AppLocalizations localization) {
    Widget bannerImage;
    if (widget.bannerImagePath != null && widget.bannerImagePath!.isNotEmpty) {
      bannerImage = Image.file(
        File(widget.bannerImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/Raco.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
          );
        },
      );
    } else {
      bannerImage = Image.asset(
        'assets/Raco.jpg',
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        },
      );
    }

    return Column(
      children: [
        Card(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              alignment: Alignment.bottomLeft,
              children: [
                bannerImage,
                Container(
                  margin: EdgeInsets.all(12.0),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Text(
                    'Project Raco $_moduleVersion',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                localization.root_access,
                _hasRootAccess ? localization.yes : localization.no,
                Icons.security_outlined,
                _hasRootAccess
                    ? Colors.green
                    : Theme.of(context).colorScheme.error,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _buildStatusCard(
                localization.mode_status_label,
                _isHamadaAiRunning
                    ? localization.mode_hamada_ai
                    : localization.mode_manual,
                Icons.settings_input_component_outlined,
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(
    String label,
    String value,
    IconData icon,
    Color valueColor,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2.0,
      // UPDATED: Changed card background color
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colorScheme.primary, size: 24),
            SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUtilitiesCard(AppLocalizations localization) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2.0,
      margin: EdgeInsets.zero,
      // UPDATED: Changed card background color
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _navigateToUtilitiesPage,
        child: Container(
          height: 56.0,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localization.utilities,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: colorScheme.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(AppLocalizations localization) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2.0,
      margin: EdgeInsets.zero,
      // UPDATED: Changed card background color
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 56.0,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              localization.select_language,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            DropdownButton<String>(
              value: _selectedLanguage,
              items: <String>['EN', 'ID', 'JP'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) _changeLanguage(newValue);
              },
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colorScheme.primary),
              // UPDATED: Changed dropdown background color
              dropdownColor: colorScheme.surfaceContainer,
              underline: Container(),
              iconEnabledColor: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlRow(
    String description,
    String scriptArg,
    String buttonText,
    IconData modeIcon,
    String modeKey,
  ) {
    final isCurrentMode = _currentMode == modeKey;
    final isExecutingThis = _executingScript == scriptArg;
    final isHamadaMode = _isHamadaAiRunning;
    final isInteractable = _hasRootAccess && _moduleInstalled;
    final colorScheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: isHamadaMode ? 0.6 : 1.0,
      child: Card(
        elevation: 2.0,
        // UPDATED: Changed inactive card background color
        color: isCurrentMode && !isHamadaMode
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: !isInteractable
              ? null
              : () {
                  if (isHamadaMode) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(
                            context,
                          )!.please_disable_hamada_ai_first,
                        ),
                      ),
                    );
                  } else if (_executingScript.isEmpty) {
                    executeScript(scriptArg, modeKey);
                  }
                },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  modeIcon,
                  size: 24,
                  color: isCurrentMode && !isHamadaMode
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buttonText,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: isCurrentMode && !isHamadaMode
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontStyle: isCurrentMode && !isHamadaMode
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              color: isCurrentMode && !isHamadaMode
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                            ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isCurrentMode && !isHamadaMode
                              ? colorScheme.onPrimaryContainer.withOpacity(0.8)
                              : colorScheme.onSurfaceVariant.withOpacity(0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                if (isExecutingThis)
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isCurrentMode && !isHamadaMode
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.primary,
                      ),
                    ),
                  )
                else if (isCurrentMode && !isHamadaMode)
                  Icon(
                    Icons.check_circle,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    color: colorScheme.onSurface,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
