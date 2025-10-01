import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:process_run/process_run.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Import to access the global themeNotifier
import '/l10n/app_localizations.dart';

//region Helper Functions
Future<ProcessResult> _runRootCommandAndWait(String command) async {
  try {
    return await run('su', ['-c', command]);
  } catch (e) {
    return ProcessResult(0, -1, '', 'Execution failed: $e');
  }
}

Future<void> _runRootCommandFireAndForget(String command) async {
  try {
    await Process.start(
      'su',
      ['-c', '$command &'],
      runInShell: true,
      mode: ProcessStartMode.detached,
    );
  } catch (e) {
    // Error starting root command
  }
}

Future<bool> _checkRootAccess() async {
  try {
    final result = await _runRootCommandAndWait('id');
    return result.exitCode == 0 && result.stdout.toString().contains('uid=0');
  } catch (e) {
    return false;
  }
}
//endregion

//region Models for Search and Navigation
class UtilityCategory {
  final String title;
  final IconData icon;
  final Widget page;

  UtilityCategory({
    required this.title,
    required this.icon,
    required this.page,
  });
}

class SearchResultItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget navigationTarget;
  final String searchKeywords;

  SearchResultItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.navigationTarget,
    required this.searchKeywords,
  });
}
//endregion

class UtilitiesPage extends StatefulWidget {
  final String? initialBackgroundImagePath;
  final double initialBackgroundOpacity;
  final double initialBackgroundBlur;

  const UtilitiesPage({
    Key? key,
    required this.initialBackgroundImagePath,
    required this.initialBackgroundOpacity,
    required this.initialBackgroundBlur,
  }) : super(key: key);

  @override
  _UtilitiesPageState createState() => _UtilitiesPageState();
}

class _UtilitiesPageState extends State<UtilitiesPage> {
  bool _isLoading = true;
  bool _hasRootAccess = false;
  bool _isContentVisible = false;
  String? _backgroundImagePath;
  double _backgroundOpacity = 0.2;
  double _backgroundBlur = 0.0;

  final TextEditingController _searchController = TextEditingController();

  List<UtilityCategory> _allCategories = [];
  List<SearchResultItem> _allSearchableItems = [];
  List<SearchResultItem> _filteredSearchResults = [];

  @override
  void initState() {
    super.initState();
    _backgroundImagePath = widget.initialBackgroundImagePath;
    _backgroundOpacity = widget.initialBackgroundOpacity;
    _backgroundBlur = widget.initialBackgroundBlur;

    _initializePage();
    _searchController.addListener(_updateSearchResults);
  }

  @override
  void dispose() {
    _searchController.removeListener(_updateSearchResults);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBackgroundPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _backgroundImagePath = prefs.getString('background_image_path');
      _backgroundOpacity = prefs.getDouble('background_opacity') ?? 0.2;
      _backgroundBlur = prefs.getDouble('background_blur') ?? 0.0;
    });
  }

  Future<void> _initializePage() async {
    final bool hasRoot = await _checkRootAccess();

    if (!mounted) return;
    setState(() {
      _hasRootAccess = hasRoot;
      _isLoading = false;
      _isContentVisible = true;
    });
  }

  void _setupData(AppLocalizations localization) {
    _allCategories = [];
    _allSearchableItems = [];

    final coreTweaksPage = CoreTweaksPage(
      backgroundImagePath: _backgroundImagePath,
      backgroundOpacity: _backgroundOpacity,
      backgroundBlur: _backgroundBlur,
    );
    _allCategories.add(
      UtilityCategory(
        title: localization.core_tweaks_title,
        icon: Icons.tune,
        page: coreTweaksPage,
      ),
    );
    _allSearchableItems.addAll([
      SearchResultItem(
        title: localization.device_mitigation_title,
        subtitle: localization.core_tweaks_title,
        icon: Icons.security_update_warning_outlined,
        navigationTarget: coreTweaksPage,
        searchKeywords: 'device mitigation fix tweak encore',
      ),
      SearchResultItem(
        title: localization.lite_mode_title,
        subtitle: localization.core_tweaks_title,
        icon: Icons.energy_savings_leaf_outlined,
        navigationTarget: coreTweaksPage,
        searchKeywords: 'lite mode battery power savings',
      ),
      SearchResultItem(
        title: localization.custom_governor_title,
        subtitle: localization.core_tweaks_title,
        icon: Icons.speed,
        navigationTarget: coreTweaksPage,
        searchKeywords: 'custom governor cpu performance',
      ),
      SearchResultItem(
        title: localization.better_powersave_title,
        subtitle: localization.core_tweaks_title,
        icon: Icons.battery_saver_outlined,
        navigationTarget: coreTweaksPage,
        searchKeywords: 'better powersave battery cpu frequency half minimum',
      ),
    ]);

    final automationPage = AutomationPage(
      backgroundImagePath: _backgroundImagePath,
      backgroundOpacity: _backgroundOpacity,
      backgroundBlur: _backgroundBlur,
    );
    _allCategories.add(
      UtilityCategory(
        title: localization.automation_title,
        icon: Icons.smart_toy_outlined,
        page: automationPage,
      ),
    );
    _allSearchableItems.addAll([
      SearchResultItem(
        title: localization.hamada_ai,
        subtitle: localization.automation_title,
        icon: Icons.smart_toy_outlined,
        navigationTarget: automationPage,
        searchKeywords: 'hamada ai automation bot',
      ),
      SearchResultItem(
        title: localization.edit_game_txt_title,
        subtitle: localization.automation_title,
        icon: Icons.edit_note,
        navigationTarget: automationPage,
        searchKeywords: 'edit game txt list apps',
      ),
    ]);

    final systemPage = SystemPage(
      backgroundImagePath: _backgroundImagePath,
      backgroundOpacity: _backgroundOpacity,
      backgroundBlur: _backgroundBlur,
    );
    _allCategories.add(
      UtilityCategory(
        title: localization.system_title,
        icon: Icons.settings_system_daydream,
        page: systemPage,
      ),
    );
    _allSearchableItems.addAll([
      SearchResultItem(
        title: localization.dnd_title,
        subtitle: localization.system_title,
        icon: Icons.do_not_disturb_on_outlined,
        navigationTarget: systemPage,
        searchKeywords: 'dnd do not disturb notifications silence',
      ),
      SearchResultItem(
        title: localization.anya_thermal_title,
        subtitle: localization.system_title,
        icon: Icons.thermostat_outlined,
        navigationTarget: systemPage,
        searchKeywords:
            'anya melfissa thermal temperature heat throttle flowstate',
      ),
      SearchResultItem(
        title: localization.bypass_charging_title,
        subtitle: localization.system_title,
        icon: Icons.bolt_outlined,
        navigationTarget: systemPage,
        searchKeywords: 'bypass charging battery power',
      ),
      SearchResultItem(
        title: localization.downscale_resolution,
        subtitle: localization.system_title,
        icon: Icons.aspect_ratio_outlined,
        navigationTarget: systemPage,
        searchKeywords: 'downscale resolution screen density display',
      ),
      SearchResultItem(
        title: localization.fstrim_title,
        subtitle: localization.system_title,
        icon: Icons.cleaning_services_outlined,
        navigationTarget: systemPage,
        searchKeywords: 'fstrim trim storage system maintenance clean',
      ),
      SearchResultItem(
        title: localization.clear_cache_title,
        subtitle: localization.system_title,
        icon: Icons.delete_sweep_outlined,
        navigationTarget: systemPage,
        searchKeywords: 'clear cache temporary files system maintenance clean',
      ),
    ]);

    final appearancePage = AppearancePage(
      initialBackgroundImagePath: _backgroundImagePath,
      initialBackgroundOpacity: _backgroundOpacity,
      initialBackgroundBlur: _backgroundBlur,
    );
    _allCategories.add(
      UtilityCategory(
        title: localization.appearance_title,
        icon: Icons.color_lens_outlined,
        page: appearancePage,
      ),
    );
    _allSearchableItems.addAll([
      SearchResultItem(
        title: localization.background_settings_title,
        subtitle: localization.appearance_title,
        icon: Icons.image_outlined,
        navigationTarget: appearancePage,
        searchKeywords: 'background image wallpaper opacity theme blur',
      ),
      SearchResultItem(
        title: localization.banner_settings_title,
        subtitle: localization.appearance_title,
        icon: Icons.panorama_outlined,
        navigationTarget: appearancePage,
        searchKeywords: 'banner image header theme color',
      ),
    ]);
  }

  void _updateSearchResults() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _filteredSearchResults = [];
        });
      }
    } else {
      final queryTerms = query.split(' ').where((t) => t.isNotEmpty).toList();
      if (mounted) {
        setState(() {
          _filteredSearchResults = _allSearchableItems.where((item) {
            final itemKeywords = item.searchKeywords.toLowerCase().split(' ');
            return queryTerms.every(
              (term) => itemKeywords.any((keyword) => keyword.startsWith(term)),
            );
          }).toList();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    if (_allCategories.isEmpty && !_isLoading) {
      _setupData(localization);
    }
    final colorScheme = Theme.of(context).colorScheme;
    final bool isSearching = _searchController.text.isNotEmpty;

    final Widget pageContent = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(localization.utilities_title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: !_hasRootAccess
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  localization.error_no_root,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            )
          : AnimatedOpacity(
              opacity: _isContentVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: localization.search_utilities,
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainer,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Expanded(
                    child: isSearching
                        ? _buildSearchResultsList()
                        : _buildCategoryList(),
                  ),
                ],
              ),
            ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Theme.of(context).colorScheme.background),
        if (_backgroundImagePath != null && _backgroundImagePath!.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: _backgroundBlur,
              sigmaY: _backgroundBlur,
            ),
            child: Opacity(
              opacity: _backgroundOpacity,
              child: Image.file(
                File(_backgroundImagePath!),
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

  Widget _buildCategoryList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      itemCount: _allCategories.length,
      itemBuilder: (context, index) {
        final category = _allCategories[index];
        return Card(
          elevation: 2.0,
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ListTile(
            leading: Icon(
              category.icon,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              category.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  opaque: false,
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      category.page,
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              ).then((_) => _loadBackgroundPreferences());
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchResultsList() {
    if (_filteredSearchResults.isEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      itemCount: _filteredSearchResults.length,
      itemBuilder: (context, index) {
        final item = _filteredSearchResults[index];
        return ListTile(
          leading: Icon(item.icon),
          title: Text(item.title),
          subtitle: Text(item.subtitle),
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                opaque: false,
                pageBuilder: (context, animation, secondaryAnimation) =>
                    item.navigationTarget,
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            ).then((_) => _loadBackgroundPreferences());
          },
        );
      },
    );
  }
}

//region Sub-Pages
// ... (All other sub-pages and cards remain the same)
class CoreTweaksPage extends StatefulWidget {
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double backgroundBlur;

  const CoreTweaksPage({
    Key? key,
    required this.backgroundImagePath,
    required this.backgroundOpacity,
    required this.backgroundBlur,
  }) : super(key: key);

  @override
  _CoreTweaksPageState createState() => _CoreTweaksPageState();
}

class _CoreTweaksPageState extends State<CoreTweaksPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _encoreState;
  Map<String, dynamic>? _governorState;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<Map<String, dynamic>> _loadEncoreSwitchState() async {
    final result = await _runRootCommandAndWait(
      'cat /data/adb/modules/ProjectRaco/raco.txt',
    );
    if (result.exitCode == 0) {
      final content = result.stdout.toString();
      return {
        'deviceMitigation':
            RegExp(
              r'^DEVICE_MITIGATION=(\d)',
              multiLine: true,
            ).firstMatch(content)?.group(1) ==
            '1',
        'liteMode':
            RegExp(
              r'^LITE_MODE=(\d)',
              multiLine: true,
            ).firstMatch(content)?.group(1) ==
            '1',
        'betterPowersave':
            RegExp(
              r'^BETTER_POWERAVE=(\d)',
              multiLine: true,
            ).firstMatch(content)?.group(1) ==
            '1',
      };
    }
    return {
      'deviceMitigation': false,
      'liteMode': false,
      'betterPowersave': false,
    };
  }

  Future<Map<String, dynamic>> _loadGovernorState() async {
    final results = await Future.wait([
      _runRootCommandAndWait(
        'cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors',
      ),
      _runRootCommandAndWait('cat /data/adb/modules/ProjectRaco/raco.txt'),
    ]);
    final governorsResult = results[0];
    final configResult = results[1];
    List<String> available =
        (governorsResult.exitCode == 0 &&
            governorsResult.stdout.toString().isNotEmpty)
        ? governorsResult.stdout.toString().trim().split(' ')
        : [];
    String? selected;
    if (configResult.exitCode == 0) {
      selected = RegExp(
        r'^GOV=(.*)$',
        multiLine: true,
      ).firstMatch(configResult.stdout.toString())?.group(1)?.trim();
    }
    return {'available': available, 'selected': selected};
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _loadEncoreSwitchState(),
      _loadGovernorState(),
    ]);

    if (!mounted) return;
    setState(() {
      _encoreState = results[0];
      _governorState = results[1];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    final Widget pageContent = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(localization.core_tweaks_title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        children: [
          FixAndTweakCard(
            initialDeviceMitigationValue:
                _encoreState?['deviceMitigation'] ?? false,
            initialLiteModeValue: _encoreState?['liteMode'] ?? false,
            initialBetterPowersaveValue:
                _encoreState?['betterPowersave'] ?? false,
          ),
          GovernorCard(
            initialAvailableGovernors: _governorState?['available'] ?? [],
            initialSelectedGovernor: _governorState?['selected'],
          ),
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
  String? _gameTxtContent;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<Map<String, bool>> _loadHamadaAiState() async {
    final results = await Future.wait([
      _runRootCommandAndWait('pgrep -x HamadaAI'),
      _runRootCommandAndWait('cat /data/adb/modules/ProjectRaco/service.sh'),
    ]);
    return {
      'enabled': results[0].exitCode == 0,
      'onBoot': results[1].stdout.toString().contains('HamadaAI'),
    };
  }

  Future<String> _loadGameTxtState() async {
    final result = await _runRootCommandAndWait(
      'cat /data/ProjectRaco/game.txt',
    );
    return result.exitCode == 0 ? result.stdout.toString() : '';
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _loadHamadaAiState(),
      _loadGameTxtState(),
    ]);

    if (!mounted) return;
    setState(() {
      _hamadaAiState = results[0] as Map<String, bool>;
      _gameTxtContent = results[1] as String;
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
          GameTxtCard(initialContent: _gameTxtContent ?? ''),
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

class SystemPage extends StatefulWidget {
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double backgroundBlur;

  const SystemPage({
    Key? key,
    required this.backgroundImagePath,
    required this.backgroundOpacity,
    required this.backgroundBlur,
  }) : super(key: key);

  @override
  _SystemPageState createState() => _SystemPageState();
}

class _SystemPageState extends State<SystemPage> {
  bool _isLoading = true;
  bool? _dndEnabled;
  bool? _anyaThermalEnabled;
  bool _isAnyaIncluded = true;
  Map<String, dynamic>? _bypassChargingState;
  Map<String, dynamic>? _resolutionState;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<bool> _loadDndState() async {
    final result = await _runRootCommandAndWait(
      'cat /data/adb/modules/ProjectRaco/raco.txt',
    );
    if (result.exitCode == 0) {
      final match = RegExp(
        r'^DND=(.*)$',
        multiLine: true,
      ).firstMatch(result.stdout.toString());
      return match?.group(1)?.trim().toLowerCase() == 'yes';
    }
    return false;
  }

  Future<bool> _loadAnyaThermalState() async {
    final result = await _runRootCommandAndWait(
      'cat /data/adb/modules/ProjectRaco/raco.txt',
    );
    if (result.exitCode == 0) {
      final match = RegExp(
        r'^ANYA=(\d)',
        multiLine: true,
      ).firstMatch(result.stdout.toString());
      return match?.group(1) == '1';
    }
    return false;
  }

  Future<bool> _loadAnyaInclusionState() async {
    final result = await _runRootCommandAndWait(
      'cat /data/adb/modules/ProjectRaco/raco.txt',
    );
    if (result.exitCode == 0) {
      final content = result.stdout.toString();
      final match = RegExp(
        r'^INCLUDE_ANYA=(\d)',
        multiLine: true,
      ).firstMatch(content);
      return match?.group(1) != '0';
    }
    return true;
  }

  Future<Map<String, dynamic>> _loadResolutionState() async {
    final results = await Future.wait([
      _runRootCommandAndWait('wm size'),
      _runRootCommandAndWait('wm density'),
    ]);
    final sr = results[0];
    final dr = results[1];
    bool available =
        sr.exitCode == 0 &&
        sr.stdout.toString().contains('Physical size:') &&
        dr.exitCode == 0 &&
        (dr.stdout.toString().contains('Physical density:') ||
            dr.stdout.toString().contains('Override density:'));
    String originalSize = '';
    int originalDensity = 0;
    if (available) {
      originalSize =
          RegExp(
            r'Physical size:\s*([0-9]+x[0-9]+)',
          ).firstMatch(sr.stdout.toString())?.group(1) ??
          '';
      originalDensity =
          int.tryParse(
            RegExp(
                  r'(?:Physical|Override) density:\s*([0-9]+)',
                ).firstMatch(dr.stdout.toString())?.group(1) ??
                '',
          ) ??
          0;
      if (originalSize.isEmpty || originalDensity == 0) available = false;
    }
    return {
      'isAvailable': available,
      'originalSize': originalSize,
      'originalDensity': originalDensity,
    };
  }

  Future<Map<String, dynamic>> _loadBypassChargingState() async {
    final results = await Future.wait([
      _runRootCommandAndWait(
        'sh /data/adb/modules/ProjectRaco/Scripts/raco_bypass_controller.sh test',
      ),
      _runRootCommandAndWait('cat /data/adb/modules/ProjectRaco/raco.txt'),
    ]);
    final supportResult = results[0];
    final configResult = results[1];
    bool isSupported = supportResult.stdout.toString().toLowerCase().contains(
      'supported',
    );
    bool isEnabled = false;
    if (configResult.exitCode == 0) {
      isEnabled =
          RegExp(r'^ENABLE_BYPASS=(Yes|No)', multiLine: true)
              .firstMatch(configResult.stdout.toString())
              ?.group(1)
              ?.toLowerCase() ==
          'yes';
    }
    return {'isSupported': isSupported, 'isEnabled': isEnabled};
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _loadDndState(),
      _loadAnyaThermalState(),
      _loadAnyaInclusionState(),
      _loadBypassChargingState(),
      _loadResolutionState(),
    ]);

    if (!mounted) return;
    setState(() {
      _dndEnabled = results[0] as bool;
      _anyaThermalEnabled = results[1] as bool;
      _isAnyaIncluded = results[2] as bool;
      _bypassChargingState = results[3] as Map<String, dynamic>;
      _resolutionState = results[4] as Map<String, dynamic>;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    final Widget pageContent = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(localization.system_title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        children: [
          DndCard(initialDndEnabled: _dndEnabled ?? false),
          if (_isAnyaIncluded)
            AnyaThermalCard(
              initialAnyaThermalEnabled: _anyaThermalEnabled ?? false,
            ),
          BypassChargingCard(
            isSupported: _bypassChargingState?['isSupported'] ?? false,
            isEnabled: _bypassChargingState?['isEnabled'] ?? false,
            supportStatus: _bypassChargingState?['isSupported'] ?? false
                ? localization.bypass_charging_supported
                : localization.bypass_charging_unsupported,
          ),
          ResolutionCard(
            isAvailable: _resolutionState?['isAvailable'] ?? false,
            originalSize: _resolutionState?['originalSize'] ?? '',
            originalDensity: _resolutionState?['originalDensity'] ?? 0,
          ),
          const SystemActionsCard(),
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

class AppearancePage extends StatefulWidget {
  final String? initialBackgroundImagePath;
  final double initialBackgroundOpacity;
  final double initialBackgroundBlur;

  const AppearancePage({
    Key? key,
    required this.initialBackgroundImagePath,
    required this.initialBackgroundOpacity,
    required this.initialBackgroundBlur,
  }) : super(key: key);
  @override
  _AppearancePageState createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  bool _isLoading = true;
  String? backgroundImagePath;
  double backgroundOpacity = 0.2;
  double backgroundBlur = 0.0;
  String? bannerImagePath;

  @override
  void initState() {
    super.initState();
    backgroundImagePath = widget.initialBackgroundImagePath;
    backgroundOpacity = widget.initialBackgroundOpacity;
    backgroundBlur = widget.initialBackgroundBlur;
    _loadAppearanceSettings();
  }

  Future<void> _loadAppearanceSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      bannerImagePath = prefs.getString('banner_image_path');
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final Widget pageContent = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(localization.appearance_title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        children: [
          BackgroundSettingsCard(
            initialPath: backgroundImagePath,
            initialOpacity: backgroundOpacity,
            initialBlur: backgroundBlur,
            onSettingsChanged: (path, opacity, blur) {
              setState(() {
                backgroundImagePath = path;
                backgroundOpacity = opacity;
                backgroundBlur = blur;
              });
            },
          ),
          BannerSettingsCard(
            initialPath: bannerImagePath,
            onSettingsChanged: (path) {
              setState(() => bannerImagePath = path);
            },
          ),
        ],
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Theme.of(context).colorScheme.background),
        if (backgroundImagePath != null && backgroundImagePath!.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: backgroundBlur,
              sigmaY: backgroundBlur,
            ),
            child: Opacity(
              opacity: backgroundOpacity,
              child: Image.file(
                File(backgroundImagePath!),
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

//region Card Widgets
class FixAndTweakCard extends StatefulWidget {
  final bool initialDeviceMitigationValue;
  final bool initialLiteModeValue;
  final bool initialBetterPowersaveValue;

  const FixAndTweakCard({
    Key? key,
    required this.initialDeviceMitigationValue,
    required this.initialLiteModeValue,
    required this.initialBetterPowersaveValue,
  }) : super(key: key);

  @override
  _FixAndTweakCardState createState() => _FixAndTweakCardState();
}

class _FixAndTweakCardState extends State<FixAndTweakCard> {
  late bool _deviceMitigationEnabled;
  late bool _liteModeEnabled;
  late bool _betterPowersaveEnabled;
  bool _isUpdatingMitigation = false;
  bool _isUpdatingLiteMode = false;
  bool _isUpdatingBetterPowersave = false;
  final String _racoConfigFilePath = '/data/adb/modules/ProjectRaco/raco.txt';

  @override
  void initState() {
    super.initState();
    _deviceMitigationEnabled = widget.initialDeviceMitigationValue;
    _liteModeEnabled = widget.initialLiteModeValue;
    _betterPowersaveEnabled = widget.initialBetterPowersaveValue;
  }

  Future<void> _updateTweak({
    required String key,
    required bool enable,
    required Function(bool) stateSetter,
    required Function(bool) isUpdatingSetter,
    required bool initialValue,
  }) async {
    if (!await _checkRootAccess()) return;
    if (mounted) setState(() => isUpdatingSetter(true));

    try {
      final value = enable ? '1' : '0';
      final sedCommand =
          "sed -i 's|^$key=.*|$key=$value|' $_racoConfigFilePath";
      final result = await _runRootCommandAndWait(sedCommand);

      if (result.exitCode == 0) {
        if (mounted) setState(() => stateSetter(enable));
      } else {
        throw Exception('Failed to write to the config file.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update settings: $e')),
        );
        setState(() => stateSetter(initialValue));
      }
    } finally {
      if (mounted) setState(() => isUpdatingSetter(false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bool isBusy =
        _isUpdatingMitigation ||
        _isUpdatingLiteMode ||
        _isUpdatingBetterPowersave;

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localization.fix_and_tweak_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SwitchListTile(
              title: Text(
                localization.device_mitigation_title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                localization.device_mitigation_description,
                style: textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              value: _deviceMitigationEnabled,
              onChanged: isBusy
                  ? null
                  : (bool enable) => _updateTweak(
                      key: 'DEVICE_MITIGATION',
                      enable: enable,
                      stateSetter: (val) => _deviceMitigationEnabled = val,
                      isUpdatingSetter: (val) => _isUpdatingMitigation = val,
                      initialValue: widget.initialDeviceMitigationValue,
                    ),
              secondary: _isUpdatingMitigation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.security_update_warning_outlined),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: Text(
                localization.lite_mode_title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                localization.lite_mode_description,
                style: textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              value: _liteModeEnabled,
              onChanged: isBusy
                  ? null
                  : (bool enable) => _updateTweak(
                      key: 'LITE_MODE',
                      enable: enable,
                      stateSetter: (val) => _liteModeEnabled = val,
                      isUpdatingSetter: (val) => _isUpdatingLiteMode = val,
                      initialValue: widget.initialLiteModeValue,
                    ),
              secondary: _isUpdatingLiteMode
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.energy_savings_leaf_outlined),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: Text(
                localization.better_powersave_title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                localization.better_powersave_description,
                style: textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              value: _betterPowersaveEnabled,
              onChanged: isBusy
                  ? null
                  : (bool enable) => _updateTweak(
                      key: 'BETTER_POWERAVE',
                      enable: enable,
                      stateSetter: (val) => _betterPowersaveEnabled = val,
                      isUpdatingSetter: (val) =>
                          _isUpdatingBetterPowersave = val,
                      initialValue: widget.initialBetterPowersaveValue,
                    ),
              secondary: _isUpdatingBetterPowersave
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.battery_saver_outlined),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class GovernorCard extends StatefulWidget {
  final List<String> initialAvailableGovernors;
  final String? initialSelectedGovernor;

  const GovernorCard({
    Key? key,
    required this.initialAvailableGovernors,
    this.initialSelectedGovernor,
  }) : super(key: key);
  @override
  _GovernorCardState createState() => _GovernorCardState();
}

class _GovernorCardState extends State<GovernorCard> {
  late List<String> _availableGovernors;
  String? _selectedGovernor;
  bool _isSaving = false;
  final String _configFilePath = '/data/adb/modules/ProjectRaco/raco.txt';

  @override
  void initState() {
    super.initState();
    _availableGovernors = widget.initialAvailableGovernors;
    _selectedGovernor = widget.initialSelectedGovernor;
  }

  Future<void> _saveGovernor(String? governor) async {
    if (!await _checkRootAccess()) return;
    if (mounted) setState(() => _isSaving = true);
    final valueString = governor ?? '';

    try {
      final sedCommand =
          "sed -i 's|^GOV=.*|GOV=$valueString|' $_configFilePath";
      final result = await _runRootCommandAndWait(sedCommand);

      if (result.exitCode == 0) {
        if (mounted) setState(() => _selectedGovernor = governor);
      } else {
        throw Exception('Failed to write to config file');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save governor: $e')));
        setState(() => _selectedGovernor = widget.initialSelectedGovernor);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
              localization.custom_governor_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.custom_governor_description,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            if (_availableGovernors.isEmpty)
              Center(
                child: Text(
                  'No governors found or root access denied.',
                  style: TextStyle(color: colorScheme.error),
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _availableGovernors.contains(_selectedGovernor)
                    ? _selectedGovernor
                    : null,
                hint: Text(localization.no_governor_selected),
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: _isSaving ? null : _saveGovernor,
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(localization.no_governor_selected),
                  ),
                  ..._availableGovernors.map<DropdownMenuItem<String>>(
                    (String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class DndCard extends StatefulWidget {
  final bool initialDndEnabled;
  const DndCard({Key? key, required this.initialDndEnabled}) : super(key: key);
  @override
  _DndCardState createState() => _DndCardState();
}

class _DndCardState extends State<DndCard> {
  late bool _dndEnabled;
  bool _isUpdating = false;
  final String _configFilePath = '/data/adb/modules/ProjectRaco/raco.txt';

  @override
  void initState() {
    super.initState();
    _dndEnabled = widget.initialDndEnabled;
  }

  Future<void> _toggleDnd(bool enable) async {
    if (!await _checkRootAccess()) return;
    if (mounted) setState(() => _isUpdating = true);
    final valueString = enable ? 'Yes' : 'No';

    try {
      final sedCommand =
          "sed -i 's|^DND=.*|DND=$valueString|' $_configFilePath";
      final result = await _runRootCommandAndWait(sedCommand);
      if (result.exitCode == 0) {
        if (mounted) setState(() => _dndEnabled = enable);
      } else {
        throw Exception('Failed to write to config file.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update DND setting: $e')),
        );
        setState(() => _dndEnabled = widget.initialDndEnabled);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
              localization.dnd_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.dnd_description,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(localization.dnd_toggle_title),
              value: _dndEnabled,
              onChanged: _isUpdating ? null : _toggleDnd,
              secondary: _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.do_not_disturb_on_outlined),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class AnyaThermalCard extends StatefulWidget {
  final bool initialAnyaThermalEnabled;
  const AnyaThermalCard({Key? key, required this.initialAnyaThermalEnabled})
    : super(key: key);
  @override
  _AnyaThermalCardState createState() => _AnyaThermalCardState();
}

class _AnyaThermalCardState extends State<AnyaThermalCard> {
  late bool _isEnabled;
  bool _isUpdating = false;
  final String _configFilePath = '/data/adb/modules/ProjectRaco/raco.txt';

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.initialAnyaThermalEnabled;
  }

  Future<void> _toggleAnyaThermal(bool enable) async {
    if (!await _checkRootAccess()) return;
    if (mounted) setState(() => _isUpdating = true);

    final valueString = enable ? '1' : '0';
    final scriptPath = enable
        ? '/data/adb/modules/ProjectRaco/Scripts/AnyaMelfissa.sh'
        : '/data/adb/modules/ProjectRaco/Scripts/AnyaKawaii.sh';

    try {
      await _runRootCommandAndWait(scriptPath);
      final sedCommand =
          "sed -i 's|^ANYA=.*|ANYA=$valueString|' $_configFilePath";
      final result = await _runRootCommandAndWait(sedCommand);

      if (result.exitCode == 0) {
        if (mounted) setState(() => _isEnabled = enable);
      } else {
        throw Exception('Failed to write to config file.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update thermal setting: $e')),
        );
        setState(() => _isEnabled = widget.initialAnyaThermalEnabled);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
              localization.anya_thermal_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.anya_thermal_description,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(localization.anya_thermal_toggle_title),
              value: _isEnabled,
              onChanged: _isUpdating ? null : _toggleAnyaThermal,
              secondary: _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.thermostat_outlined),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
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
    if (!await _checkRootAccess()) {
      return {'enabled': _hamadaAiEnabled, 'onBoot': _hamadaStartOnBoot};
    }
    final results = await Future.wait([
      _runRootCommandAndWait('pgrep -x HamadaAI'),
      _runRootCommandAndWait('cat $_serviceFilePath'),
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
    if (!await _checkRootAccess()) return;
    if (mounted) setState(() => _isTogglingProcess = true);
    try {
      if (enable) {
        await _runRootCommandFireAndForget(_hamadaStartCommand);
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        await _runRootCommandAndWait('killall HamadaAI');
      }
      await _refreshState();
    } finally {
      if (mounted) setState(() => _isTogglingProcess = false);
    }
  }

  Future<void> _setHamadaStartOnBoot(bool enable) async {
    if (!await _checkRootAccess()) return;
    if (mounted) setState(() => _isTogglingBoot = true);
    try {
      String content = (await _runRootCommandAndWait(
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
      final result = await _runRootCommandAndWait(writeCmd);

      if (result.exitCode == 0) {
        if (mounted) setState(() => _hamadaStartOnBoot = enable);
      } else {
        throw Exception('Failed to write to service file');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update boot setting: $e')),
        );
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

class ResolutionCard extends StatefulWidget {
  final bool isAvailable;
  final String originalSize;
  final int originalDensity;
  const ResolutionCard({
    Key? key,
    required this.isAvailable,
    required this.originalSize,
    required this.originalDensity,
  }) : super(key: key);
  @override
  _ResolutionCardState createState() => _ResolutionCardState();
}

class _ResolutionCardState extends State<ResolutionCard> {
  bool _isChanging = false;
  late double _currentValue;
  final List<int> _percentages = [50, 60, 70, 80, 90, 100];

  @override
  void initState() {
    super.initState();
    _currentValue = (_percentages.length - 1).toDouble();
  }

  @override
  void dispose() {
    if (widget.isAvailable &&
        _currentValue != (_percentages.length - 1).toDouble()) {
      _resetResolution(showSnackbar: false);
    }
    super.dispose();
  }

  String _getCurrentPercentageLabel() {
    int idx = _currentValue.round().clamp(0, _percentages.length - 1);
    return '${_percentages[idx]}%';
  }

  Future<void> _applyResolution(double value) async {
    if (!widget.isAvailable ||
        widget.originalSize.isEmpty ||
        widget.originalDensity <= 0)
      return;
    if (mounted) setState(() => _isChanging = true);

    final idx = value.round().clamp(0, _percentages.length - 1);
    final pct = _percentages[idx];

    try {
      final parts = widget.originalSize.split('x');
      final newW = (int.parse(parts[0]) * pct / 100).floor();
      final newH = (int.parse(parts[1]) * pct / 100).floor();
      final newD = (widget.originalDensity * pct / 100).floor();

      if (newW <= 0 || newH <= 0 || newD <= 0) throw Exception('Invalid dims');

      await _runRootCommandAndWait('wm size ${newW}x$newH');
      await _runRootCommandAndWait('wm density $newD');

      if (mounted) setState(() => _currentValue = value);
    } catch (e) {
      await _resetResolution();
    } finally {
      if (mounted) setState(() => _isChanging = false);
    }
  }

  Future<void> _resetResolution({bool showSnackbar = true}) async {
    if (!widget.isAvailable) return;
    if (mounted) setState(() => _isChanging = true);
    try {
      await _runRootCommandAndWait('wm size reset');
      await _runRootCommandAndWait('wm density reset');
      if (mounted) {
        setState(() => _currentValue = (_percentages.length - 1).toDouble());
      }
    } finally {
      if (mounted) setState(() => _isChanging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
              localization.downscale_resolution,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (!widget.isAvailable)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  localization.resolution_unavailable_message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              Row(
                children: [
                  Icon(
                    Icons.aspect_ratio_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: _currentValue,
                      min: 0,
                      max: (_percentages.length - 1).toDouble(),
                      divisions: _percentages.length - 1,
                      label: _getCurrentPercentageLabel(),
                      onChanged: _isChanging
                          ? null
                          : (double value) {
                              if (mounted) {
                                setState(() => _currentValue = value);
                              }
                            },
                      onChangeEnd: _isChanging ? null : _applyResolution,
                    ),
                  ),
                  Text(
                    _getCurrentPercentageLabel(),
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isChanging ? null : _resetResolution,
                  icon: _isChanging
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(localization.reset_resolution),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class GameTxtCard extends StatefulWidget {
  final String initialContent;
  const GameTxtCard({Key? key, required this.initialContent}) : super(key: key);
  @override
  _GameTxtCardState createState() => _GameTxtCardState();
}

class _GameTxtCardState extends State<GameTxtCard> {
  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GameTxtEditorPage(
                        initialContent: widget.initialContent,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_note),
                label: Text(localization.edit_game_txt_title),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom controller to handle search term highlighting
class _HighlightingTextController extends TextEditingController {
  List<TextRange> _matches;
  final Color highlightColor;

  _HighlightingTextController({
    required this.highlightColor,
    List<TextRange> matches = const [],
    String? text,
  }) : _matches = matches,
       super(text: text);

  void set matches(List<TextRange> newMatches) {
    _matches = newMatches;
    // This call is crucial to trigger a rebuild of the text span.
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<InlineSpan> children = [];
    int lastMatchEnd = 0;

    // If there's no search query or no matches, return the plain text.
    if (_matches.isEmpty || text.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    // Sort matches to process them in order.
    _matches.sort((a, b) => a.start.compareTo(b.start));

    for (final TextRange match in _matches) {
      // Add the text before the current match
      if (match.start > lastMatchEnd) {
        children.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: style,
          ),
        );
      }

      // Add the highlighted match
      children.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: style?.copyWith(
            backgroundColor: highlightColor.withOpacity(0.3), // Use theme color
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    // Add the remaining text after the last match
    if (lastMatchEnd < text.length) {
      children.add(TextSpan(text: text.substring(lastMatchEnd), style: style));
    }

    return TextSpan(style: style, children: children);
  }
}

class GameTxtEditorPage extends StatefulWidget {
  final String initialContent;
  const GameTxtEditorPage({Key? key, required this.initialContent})
    : super(key: key);
  @override
  _GameTxtEditorPageState createState() => _GameTxtEditorPageState();
}

class _GameTxtEditorPageState extends State<GameTxtEditorPage> {
  late _HighlightingTextController _textController;
  final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;
  bool _isSearching = false;
  String _searchQuery = '';
  int _currentMatchIndex = -1;
  final String _gameTxtPath = '/data/ProjectRaco/game.txt';

  @override
  void initState() {
    super.initState();
    _textController = _HighlightingTextController(
      text: widget.initialContent,
      highlightColor: Colors.transparent, // Placeholder color
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update the highlight color to match the current theme's primary color.
    _textController = _HighlightingTextController(
      text: _textController.text,
      matches: _textController._matches,
      highlightColor: Theme.of(context).colorScheme.primary,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _textController.matches = [];
        _currentMatchIndex = -1;
      });
      return;
    }

    final text = _textController.text.toLowerCase();
    final searchLower = query.toLowerCase();
    final List<TextRange> matches = <TextRange>[];

    int startIndex = 0;
    while (true) {
      final index = text.indexOf(searchLower, startIndex);
      if (index == -1) break;
      matches.add(TextRange(start: index, end: index + searchLower.length));
      startIndex = index + 1;
    }

    setState(() {
      _textController.matches = matches;
      _currentMatchIndex = matches.isNotEmpty ? 0 : -1;
    });

    if (matches.isNotEmpty) {
      _scrollToMatch(0);
    }
  }

  void _scrollToMatch(int index) {
    final matches = _textController._matches;
    if (index < 0 || index >= matches.length) return;

    final match = matches[index];
    final text = _textController.text.substring(0, match.start);
    final lines = text.split('\n').length;

    // Approximate scroll position (20.0 is approximate line height)
    final offset = (lines - 1) * 20.0;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextMatch() {
    final matches = _textController._matches;
    if (matches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % matches.length;
    });
    _scrollToMatch(_currentMatchIndex);
  }

  void _previousMatch() {
    final matches = _textController._matches;
    if (matches.isEmpty) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + matches.length) % matches.length;
    });
    _scrollToMatch(_currentMatchIndex);
  }

  Future<void> _saveContent() async {
    if (!await _checkRootAccess()) return;
    if (mounted) setState(() => _isSaving = true);
    final newContent = _textController.text;
    try {
      String base64Content = base64Encode(utf8.encode(newContent));
      final writeCmd = '''echo '$base64Content' | base64 -d > $_gameTxtPath''';
      await _runRootCommandAndWait(writeCmd);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error saving game.txt')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (_textController.highlightColor != colorScheme.primary) {
      _textController = _HighlightingTextController(
        text: _textController.text,
        matches: _textController._matches,
        highlightColor: colorScheme.primary,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.edit_game_txt_title),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: localization.search_title,
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            tooltip: localization.save_tooltip,
            onPressed: _isSaving ? null : _saveContent,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearching)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: localization.search_hint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                        _performSearch(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_textController._matches.isNotEmpty)
                    Text(
                      '${_currentMatchIndex + 1}/${_textController._matches.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up),
                    onPressed: _textController._matches.isEmpty
                        ? null
                        : _previousMatch,
                    iconSize: 20,
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: _textController._matches.isEmpty
                        ? null
                        : _nextMatch,
                    iconSize: 20,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: localization.close_search_tooltip,
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchQuery = '';
                        _textController.matches = [];
                        _currentMatchIndex = -1;
                      });
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: null,
              expands: true,
              scrollController: _scrollController,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                hintText: localization.game_txt_hint,
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class BypassChargingCard extends StatefulWidget {
  final bool isSupported;
  final bool isEnabled;
  final String supportStatus;
  const BypassChargingCard({
    Key? key,
    required this.isSupported,
    required this.isEnabled,
    required this.supportStatus,
  }) : super(key: key);
  @override
  _BypassChargingCardState createState() => _BypassChargingCardState();
}

class _BypassChargingCardState extends State<BypassChargingCard> {
  late bool _isEnabled;
  bool _isToggling = false;

  final String _configFilePath = '/data/adb/modules/ProjectRaco/raco.txt';

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.isEnabled;
  }

  Future<void> _toggleBypass(bool enable) async {
    if (!await _checkRootAccess()) return;
    if (mounted) setState(() => _isToggling = true);

    try {
      final value = enable ? 'Yes' : 'No';
      final sedCommand =
          "sed -i 's|^ENABLE_BYPASS=.*|ENABLE_BYPASS=$value|' $_configFilePath";
      await _runRootCommandAndWait(sedCommand);

      if (mounted) setState(() => _isEnabled = enable);
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
              localization.bypass_charging_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.bypass_charging_description,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                widget.supportStatus,
                style: textTheme.bodyMedium?.copyWith(
                  color: widget.isSupported ? Colors.green : colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(localization.bypass_charging_toggle),
              value: _isEnabled,
              onChanged: (_isToggling || !widget.isSupported)
                  ? null
                  : _toggleBypass,
              secondary: _isToggling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt_outlined),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class SystemActionsCard extends StatefulWidget {
  const SystemActionsCard({Key? key}) : super(key: key);

  @override
  _SystemActionsCardState createState() => _SystemActionsCardState();
}

class _SystemActionsCardState extends State<SystemActionsCard> {
  bool _isFstrimRunning = false;
  bool _isClearCacheRunning = false;

  Future<void> _runAction({
    required String command,
    required Function(bool) setLoadingState,
  }) async {
    if (!await _checkRootAccess()) return;
    if (mounted) setState(() => setLoadingState(true));

    try {
      final result = await _runRootCommandAndWait(command);
      if (result.exitCode != 0) {
        throw Exception(result.stderr);
      }
    } catch (e) {
      // Errors can be logged or handled here if necessary.
    } finally {
      if (mounted) setState(() => setLoadingState(false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bool isBusy = _isFstrimRunning || _isClearCacheRunning;

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
              localization.system_actions_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            // Fstrim Action
            ListTile(
              leading: _isFstrimRunning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.cleaning_services_outlined),
              title: Text(localization.fstrim_title),
              subtitle: Text(
                localization.fstrim_description,
                style: textTheme.bodySmall,
              ),
              trailing: ElevatedButton(
                onPressed: isBusy
                    ? null
                    : () => _runAction(
                        command:
                            'su -c sh /data/adb/modules/ProjectRaco/Scripts/Fstrim.sh',
                        setLoadingState: (val) => _isFstrimRunning = val,
                      ),
                child: const Icon(Icons.play_arrow),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            // Clear Cache Action
            ListTile(
              leading: _isClearCacheRunning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.delete_sweep_outlined),
              title: Text(localization.clear_cache_title),
              trailing: ElevatedButton(
                onPressed: isBusy
                    ? null
                    : () => _runAction(
                        command:
                            'su -c sh /data/adb/modules/ProjectRaco/Scripts/Clear_cache.sh',
                        setLoadingState: (val) => _isClearCacheRunning = val,
                      ),
                child: const Icon(Icons.play_arrow),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class BackgroundSettingsCard extends StatefulWidget {
  final String? initialPath;
  final double initialOpacity;
  final double initialBlur;
  final Function(String?, double, double) onSettingsChanged;

  const BackgroundSettingsCard({
    Key? key,
    required this.initialPath,
    required this.initialOpacity,
    required this.initialBlur,
    required this.onSettingsChanged,
  }) : super(key: key);

  @override
  _BackgroundSettingsCardState createState() => _BackgroundSettingsCardState();
}

class _BackgroundSettingsCardState extends State<BackgroundSettingsCard> {
  late String? _path;
  late double _opacity;
  late double _blurPercentage;
  final double _maxSigma = 15.0;

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
    _opacity = widget.initialOpacity;
    _blurPercentage = (widget.initialBlur / _maxSigma * 100.0).clamp(
      0.0,
      100.0,
    );
  }

  @override
  void didUpdateWidget(BackgroundSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPath != oldWidget.initialPath ||
        widget.initialOpacity != oldWidget.initialOpacity ||
        widget.initialBlur != oldWidget.initialBlur) {
      if (mounted) {
        setState(() {
          _path = widget.initialPath;
          _opacity = widget.initialOpacity;
          _blurPercentage = (widget.initialBlur / _maxSigma * 100.0).clamp(
            0.0,
            100.0,
          );
        });
      }
    }
  }

  double get _currentSigmaValue => (_blurPercentage / 100.0 * _maxSigma);

  Future<void> _pickAndSetImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('background_image_path', pickedFile.path);
        if (mounted) {
          setState(() => _path = pickedFile.path);
        }
        widget.onSettingsChanged(_path, _opacity, _currentSigmaValue);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _updateOpacity(double opacity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('background_opacity', opacity);
    widget.onSettingsChanged(_path, opacity, _currentSigmaValue);
  }

  Future<void> _updateBlur(double percentage) async {
    final sigmaValue = (percentage / 100.0 * _maxSigma);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('background_blur', sigmaValue);
    widget.onSettingsChanged(_path, _opacity, sigmaValue);
  }

  Future<void> _resetBackground() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('background_image_path');
    await prefs.setDouble('background_opacity', 0.2);
    await prefs.remove('background_blur');
    if (mounted) {
      setState(() {
        _path = null;
        _opacity = 0.2;
        _blurPercentage = 0.0;
      });
    }
    widget.onSettingsChanged(null, 0.2, 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
              localization.background_settings_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.background_settings_description,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            Text(
              localization.opacity_slider_label,
              style: textTheme.bodyMedium,
            ),
            Slider(
              value: _opacity,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              label: '${(_opacity * 100).toStringAsFixed(0)}%',
              onChanged: (value) {
                if (mounted) {
                  setState(() => _opacity = value);
                }
                widget.onSettingsChanged(_path, value, _currentSigmaValue);
              },
              onChangeEnd: _updateOpacity,
            ),
            Text(localization.blur_slider_label, style: textTheme.bodyMedium),
            Slider(
              value: _blurPercentage,
              min: 0.0,
              max: 100.0,
              divisions: 100,
              label: '${_blurPercentage.round()}%',
              onChanged: (value) {
                if (mounted) {
                  setState(() => _blurPercentage = value);
                }
                final currentSigma = (value / 100.0 * _maxSigma);
                widget.onSettingsChanged(_path, _opacity, currentSigma);
              },
              onChangeEnd: _updateBlur,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _pickAndSetImage,
                    child: const Icon(Icons.image_outlined),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _resetBackground,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.errorContainer,
                      foregroundColor: colorScheme.onErrorContainer,
                    ),
                    child: const Icon(Icons.delete_outline),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BannerSettingsCard extends StatefulWidget {
  final String? initialPath;
  final Function(String?) onSettingsChanged;

  const BannerSettingsCard({
    Key? key,
    required this.initialPath,
    required this.onSettingsChanged,
  }) : super(key: key);

  @override
  _BannerSettingsCardState createState() => _BannerSettingsCardState();
}

class _BannerSettingsCardState extends State<BannerSettingsCard> {
  late String? _path;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
  }

  @override
  void didUpdateWidget(BannerSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPath != oldWidget.initialPath) {
      if (mounted) {
        setState(() {
          _path = widget.initialPath;
        });
      }
    }
  }

  // NEW: Calculate, save, and notify the app of the new seed color.
  Future<void> _generateAndSaveSeedColor(String? imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'banner_seed_color';
    Color? newColor;

    if (imagePath == null || imagePath.isEmpty) {
      await prefs.remove(key);
      newColor = null;
    } else {
      try {
        final int? seedColorValue = await compute(
          _calculateSeedColor,
          imagePath,
        );
        if (seedColorValue != null) {
          await prefs.setInt(key, seedColorValue);
          newColor = Color(seedColorValue);
        } else {
          await prefs.remove(key);
          newColor = null;
        }
      } catch (e) {
        await prefs.remove(key);
        newColor = null;
      }
    }
    // This notifies the listener in main.dart to rebuild the app with the new theme.
    themeNotifier.value = newColor;
  }

  Future<void> _pickAndCropImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile == null || !mounted) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Banner',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Theme.of(context).colorScheme.onPrimary,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Banner',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        setState(() => _isProcessing = true);
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await File(
          croppedFile.path,
        ).copy(p.join(appDir.path, fileName));

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('banner_image_path', savedImage.path);

        // Calculate, save, and notify the app of the new seed color
        await _generateAndSaveSeedColor(savedImage.path);

        if (mounted) {
          setState(() {
            _path = savedImage.path;
            _isProcessing = false;
          });
        }
        widget.onSettingsChanged(_path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick or crop image: $e')),
        );
      }
    }
  }

  Future<void> _resetBanner() async {
    setState(() => _isProcessing = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('banner_image_path');

    // Remove the saved seed color and notify the app
    await _generateAndSaveSeedColor(null);

    if (mounted) {
      setState(() {
        _path = null;
        _isProcessing = false;
      });
    }
    widget.onSettingsChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
              localization.banner_settings_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.banner_settings_description,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            if (_isProcessing)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  // UPDATED: Show text with a loading spinner
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        localization.applying_new_color,
                        style: textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _pickAndCropImage,
                      child: const Icon(Icons.image_outlined),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _resetBanner,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.errorContainer,
                        foregroundColor: colorScheme.onErrorContainer,
                      ),
                      child: const Icon(Icons.delete_outline),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// NEW: Top-level function for isolate computation. It's safer this way.
@visibleForTesting
Future<int?> _calculateSeedColor(String imagePath) async {
  try {
    final file = File(imagePath);
    final imageBytes = await file.readAsBytes();
    final image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('Failed to decode image in isolate');
    }

    final rgbaBytes = image.getBytes(order: img.ChannelOrder.rgba);
    final pixels = <int>[];
    for (var i = 0; i < rgbaBytes.length; i += 4) {
      final r = rgbaBytes[i];
      final g = rgbaBytes[i + 1];
      final b = rgbaBytes[i + 2];
      final a = rgbaBytes[i + 3];
      pixels.add((a << 24) | (r << 16) | (g << 8) | b);
    }

    final quantizer = QuantizerCelebi();
    final quantizedColors = await quantizer.quantize(pixels, 128);
    final rankedColors = Score.score(quantizedColors.colorToCount);
    return rankedColors.first;
  } catch (e) {
    // Return null if any part of the calculation fails
    return null;
  }
}
