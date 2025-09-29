import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:process_run/process_run.dart';
import '/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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

// NEW: A model for an individual search result item.
class SearchResultItem {
  final String title;
  final String subtitle; // The name of the parent category
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
  const UtilitiesPage({Key? key}) : super(key: key);

  @override
  _UtilitiesPageState createState() => _UtilitiesPageState();
}

class _UtilitiesPageState extends State<UtilitiesPage> {
  bool _isLoading = true;
  bool _hasRootAccess = false;
  bool _isContentVisible = false;
  String? _backgroundImagePath;
  double _backgroundOpacity = 0.2;

  final TextEditingController _searchController = TextEditingController();

  // Lists for the default category view
  List<UtilityCategory> _allCategories = [];

  // NEW: Lists to manage individual searchable items and their filtered results
  List<SearchResultItem> _allSearchableItems = [];
  List<SearchResultItem> _filteredSearchResults = [];

  @override
  void initState() {
    super.initState();
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
    });
  }

  // MODIFIED: This page now only checks for root access.
  // All other data loading is deferred to the sub-pages.
  Future<void> _initializePage() async {
    await _loadBackgroundPreferences();
    final bool hasRoot = await _checkRootAccess();

    if (!mounted) return;
    setState(() {
      _hasRootAccess = hasRoot;
      _isLoading = false;
      _isContentVisible = true;
    });
  }

  // MODIFIED: This method now populates both the categories and the individual searchable items.
  // The sub-pages are now created without any initial data.
  void _setupData(AppLocalizations localization) {
    // Clear lists to prevent duplication on rebuild
    _allCategories = [];
    _allSearchableItems = [];

    // --- Core Tweaks ---
    const coreTweaksPage = CoreTweaksPage();
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
    ]);

    // --- Automation ---
    const automationPage = AutomationPage();
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

    // --- System ---
    const systemPage = SystemPage();
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
      // The Anya item is now conditionally added inside the SystemPage itself
      // after checking if it's included. For search, we can assume it might exist.
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

    // --- Appearance ---
    const appearancePage = AppearancePage();
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
        searchKeywords: 'background image wallpaper opacity theme',
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
            // Hide Anya from search if we know it's not included.
            // This is an optimistic search; for a perfect solution,
            // we'd need to load the 'anya included' state here,
            // but that defeats the purpose of lazy loading.
            // This approach is a good compromise.
            if (item.searchKeywords.contains('anya')) {
              // A simple heuristic could be added here if needed
            }

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
      body: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: LinearProgressIndicator(),
              ),
            )
          : !_hasRootAccess
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
                    // NEW: Conditionally show category list or search results list
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
        pageContent,
      ],
    );
  }

  /// Builds the default list of utility categories.
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

  /// Builds the list of individual search results.
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

//region Sub-Pages and Cards

//region Sub-Pages
class CoreTweaksPage extends StatefulWidget {
  const CoreTweaksPage({Key? key}) : super(key: key);

  @override
  _CoreTweaksPageState createState() => _CoreTweaksPageState();
}

class _CoreTweaksPageState extends State<CoreTweaksPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _encoreState;
  Map<String, dynamic>? _governorState;
  String? _backgroundImagePath;
  double _backgroundOpacity = 0.2;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadBackgroundPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _backgroundImagePath = prefs.getString('background_image_path');
      _backgroundOpacity = prefs.getDouble('background_opacity') ?? 0.2;
    });
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
      };
    }
    return {'deviceMitigation': false, 'liteMode': false};
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
    await _loadBackgroundPreferences();
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
      body: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: LinearProgressIndicator(),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
              children: [
                FixAndTweakCard(
                  initialDeviceMitigationValue:
                      _encoreState?['deviceMitigation'] ?? false,
                  initialLiteModeValue: _encoreState?['liteMode'] ?? false,
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
        if (_backgroundImagePath != null && _backgroundImagePath!.isNotEmpty)
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
        pageContent,
      ],
    );
  }
}

class AutomationPage extends StatefulWidget {
  const AutomationPage({Key? key}) : super(key: key);

  @override
  _AutomationPageState createState() => _AutomationPageState();
}

class _AutomationPageState extends State<AutomationPage> {
  bool _isLoading = true;
  Map<String, bool>? _hamadaAiState;
  String? _gameTxtContent;
  String? _backgroundImagePath;
  double _backgroundOpacity = 0.2;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadBackgroundPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _backgroundImagePath = prefs.getString('background_image_path');
      _backgroundOpacity = prefs.getDouble('background_opacity') ?? 0.2;
    });
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
    await _loadBackgroundPreferences();
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
      body: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: LinearProgressIndicator(),
              ),
            )
          : ListView(
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
        if (_backgroundImagePath != null && _backgroundImagePath!.isNotEmpty)
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
        pageContent,
      ],
    );
  }
}

class SystemPage extends StatefulWidget {
  const SystemPage({Key? key}) : super(key: key);

  @override
  _SystemPageState createState() => _SystemPageState();
}

class _SystemPageState extends State<SystemPage> {
  bool _isLoading = true;
  bool? _dndEnabled;
  bool? _anyaThermalEnabled;
  bool _isAnyaIncluded = true; // Assume true until proven otherwise
  Map<String, dynamic>? _bypassChargingState;
  Map<String, dynamic>? _resolutionState;
  String? _backgroundImagePath;
  double _backgroundOpacity = 0.2;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadBackgroundPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _backgroundImagePath = prefs.getString('background_image_path');
      _backgroundOpacity = prefs.getDouble('background_opacity') ?? 0.2;
    });
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
      // Hide if INCLUDE_ANYA=0. Show otherwise.
      return match?.group(1) != '0';
    }
    // Default to showing if file/line is not found.
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
    await _loadBackgroundPreferences();
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
      body: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: LinearProgressIndicator(),
              ),
            )
          : ListView(
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
        if (_backgroundImagePath != null && _backgroundImagePath!.isNotEmpty)
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
        pageContent,
      ],
    );
  }
}

class AppearancePage extends StatefulWidget {
  const AppearancePage({Key? key}) : super(key: key);
  @override
  _AppearancePageState createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  bool _isLoading = true;
  String? backgroundImagePath;
  double backgroundOpacity = 0.2;
  String? bannerImagePath;

  @override
  void initState() {
    super.initState();
    _loadAppearanceSettings();
  }

  Future<void> _loadAppearanceSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      backgroundImagePath = prefs.getString('background_image_path');
      backgroundOpacity = prefs.getDouble('background_opacity') ?? 0.2;
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
      body: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: LinearProgressIndicator(),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
              children: [
                BackgroundSettingsCard(
                  initialPath: backgroundImagePath,
                  initialOpacity: backgroundOpacity,
                  onSettingsChanged: (path, opacity) {
                    setState(() {
                      backgroundImagePath = path;
                      backgroundOpacity = opacity;
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
          Opacity(
            opacity: backgroundOpacity,
            child: Image.file(
              File(backgroundImagePath!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.transparent);
              },
            ),
          ),
        pageContent,
      ],
    );
  }
}
//endregion

//region Card Widgets
class FixAndTweakCard extends StatefulWidget {
  final bool initialDeviceMitigationValue;
  final bool initialLiteModeValue;

  const FixAndTweakCard({
    Key? key,
    required this.initialDeviceMitigationValue,
    required this.initialLiteModeValue,
  }) : super(key: key);

  @override
  _FixAndTweakCardState createState() => _FixAndTweakCardState();
}

class _FixAndTweakCardState extends State<FixAndTweakCard> {
  late bool _deviceMitigationEnabled;
  late bool _liteModeEnabled;
  bool _isUpdatingMitigation = false;
  bool _isUpdatingLiteMode = false;
  final String _racoConfigFilePath = '/data/adb/modules/ProjectRaco/raco.txt';

  @override
  void initState() {
    super.initState();
    _deviceMitigationEnabled = widget.initialDeviceMitigationValue;
    _liteModeEnabled = widget.initialLiteModeValue;
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
    final bool isBusy = _isUpdatingMitigation || _isUpdatingLiteMode;

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
      // First, run the appropriate script to enable/disable the thermal mod
      await _runRootCommandAndWait(scriptPath);

      // Then, update the configuration file to reflect the state
      final sedCommand =
          "sed -i 's|^ANYA=.*|ANYA=$valueString|' $_configFilePath";
      final result = await _runRootCommandAndWait(sedCommand);

      if (result.exitCode == 0) {
        if (mounted) setState(() => _isEnabled = enable);
      } else {
        // If updating the config fails, consider the whole operation failed.
        throw Exception('Failed to write to config file.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update thermal setting: $e')),
        );
        // Revert the UI state if any part of the operation fails
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
  final _controller = TextEditingController();
  bool _isSaving = false;
  final String _gameTxtPath = '/data/ProjectRaco/game.txt';

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialContent;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveContent() async {
    if (!await _checkRootAccess()) return;
    if (mounted) setState(() => _isSaving = true);
    final newContent = _controller.text;
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
            TextField(
              controller: _controller,
              maxLines: 10,
              minLines: 5,
              enabled: !_isSaving,
              decoration: InputDecoration(
                hintText: localization.game_txt_hint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                contentPadding: const EdgeInsets.all(12),
              ),
              style: textTheme.bodyMedium?.copyWith(fontSize: 14.0),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveContent,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(localization.save_button),
              ),
            ),
          ],
        ),
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
  final Function(String?, double) onSettingsChanged;

  const BackgroundSettingsCard({
    Key? key,
    required this.initialPath,
    required this.initialOpacity,
    required this.onSettingsChanged,
  }) : super(key: key);

  @override
  _BackgroundSettingsCardState createState() => _BackgroundSettingsCardState();
}

class _BackgroundSettingsCardState extends State<BackgroundSettingsCard> {
  late String? _path;
  late double _opacity;

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
    _opacity = widget.initialOpacity;
  }

  @override
  void didUpdateWidget(BackgroundSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPath != oldWidget.initialPath ||
        widget.initialOpacity != oldWidget.initialOpacity) {
      if (mounted) {
        setState(() {
          _path = widget.initialPath;
          _opacity = widget.initialOpacity;
        });
      }
    }
  }

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
        widget.onSettingsChanged(_path, _opacity);
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
    widget.onSettingsChanged(_path, opacity);
  }

  Future<void> _resetBackground() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('background_image_path');
    await prefs.setDouble('background_opacity', 0.2);
    if (mounted) {
      setState(() {
        _path = null;
        _opacity = 0.2;
      });
    }
    widget.onSettingsChanged(null, 0.2);
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
                widget.onSettingsChanged(_path, value);
              },
              onChangeEnd: _updateOpacity,
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
            rectX: 1.0,
            rectY: 1.0,
            rectWidth: 1280,
            rectHeight: 720,
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await File(
          croppedFile.path,
        ).copy(p.join(appDir.path, fileName));

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('banner_image_path', savedImage.path);
        if (mounted) {
          setState(() => _path = savedImage.path);
        }
        widget.onSettingsChanged(_path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick or crop image: $e')),
        );
      }
    }
  }

  Future<void> _resetBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('banner_image_path');
    if (mounted) {
      setState(() {
        _path = null;
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
