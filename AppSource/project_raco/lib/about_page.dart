import 'package:flutter/material.dart';
import 'package:process_run/process_run.dart';
import '/l10n/app_localizations.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class AboutPage extends StatefulWidget {
  AboutPage({Key? key}) : super(key: key);

  @override
  _AboutPageState createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _deviceModel = 'Loading...';
  String _cpuInfo = 'Loading...';
  String _ramInfo = 'Loading...';
  String _storageInfo = 'Loading...';
  String _batteryInfo = 'Loading...';
  bool _isLoading = true;

  String? _backgroundImagePath;
  double _backgroundOpacity = 0.2;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([_loadBackgroundSettings(), _loadDeviceInfo()]);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBackgroundSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final path = prefs.getString('background_image_path');
      final opacity = prefs.getDouble('background_opacity') ?? 0.2;
      setState(() {
        _backgroundImagePath = path;
        _backgroundOpacity = opacity;
      });
    } catch (e) {
      // Error loading background settings
    }
  }

  Future<bool> _checkRootAccessInAbout() async {
    try {
      var result = await run('su', ['-c', 'id'], verbose: false);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadDeviceInfo() async {
    final rootGranted = await _checkRootAccessInAbout();

    String deviceModel = 'N/A';
    String cpuInfo = 'N/A';
    String ramInfo = 'N/A';
    String storageInfo = 'N/A';
    String batteryInfo = 'N/A';

    if (rootGranted) {
      try {
        final results = await Future.wait([
          // 0: Device Model
          run('su', ['-c', 'getprop ro.product.model'], verbose: false),
          // 1: CPU Platform
          run('su', ['-c', 'getprop ro.board.platform'], verbose: false),
          // 2: CPU Hardware
          run('su', ['-c', 'getprop ro.hardware'], verbose: false),
          // 3: CPU Hardware from /proc/cpuinfo
          run('su', [
            '-c',
            'cat /proc/cpuinfo | grep Hardware | cut -d: -f2',
          ], verbose: false),
          // 4: CPU Max Freq
          run('su', [
            '-c',
            'cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq',
          ], verbose: false),
          // 5: Total RAM
          run('su', [
            '-c',
            r"cat /proc/meminfo | grep MemTotal | awk '{print $2}'",
          ], verbose: false),
          // 6: Total Storage
          run('su', [
            '-c',
            r"df /data | tail -n 1 | awk '{print $2}'",
          ], verbose: false),
          // 7: Battery Capacity
          run('su', [
            '-c',
            'cat /sys/class/power_supply/battery/charge_full_design',
          ], verbose: false),
        ]);

        // Device Model
        deviceModel = results[0].stdout.toString().trim();

        // CPU Info
        String cpuName = results[1].stdout.toString().trim();
        if (cpuName.isEmpty || cpuName.toLowerCase() == 'unknown') {
          cpuName = results[2].stdout.toString().trim();
        }
        if (cpuName.isEmpty || cpuName.toLowerCase() == 'unknown') {
          cpuName = results[3].stdout.toString().trim();
        }

        String cpuFreq = results[4].stdout.toString().trim();
        if (cpuFreq.isNotEmpty && int.tryParse(cpuFreq) != null) {
          double freqGhz = int.parse(cpuFreq) / 1000000;
          cpuInfo = '${freqGhz.toStringAsFixed(2)}GHz $cpuName';
        } else {
          cpuInfo = cpuName;
        }

        // RAM Info
        String totalRamKb = results[5].stdout.toString().trim();
        if (totalRamKb.isNotEmpty && int.tryParse(totalRamKb) != null) {
          double totalRamGb = int.parse(totalRamKb) / (1024 * 1024);
          // --- FIX: Changed .round() to .ceil() to always round up ---
          ramInfo = '${totalRamGb.ceil()} GB';
        }

        // Storage Info
        String totalStorageKb = results[6].stdout.toString().trim();
        if (totalStorageKb.isNotEmpty && int.tryParse(totalStorageKb) != null) {
          double totalStorageGb = int.parse(totalStorageKb) / (1024 * 1024);
          // Use powers of 1000 for storage as is common marketing practice
          if (totalStorageGb > 500) {
            storageInfo = '1 TB';
          } else if (totalStorageGb > 240) {
            storageInfo = '512 GB';
          } else if (totalStorageGb > 200) {
            storageInfo = '256 GB';
          } else if (totalStorageGb > 100) {
            storageInfo = '128 GB';
          } else if (totalStorageGb > 50) {
            storageInfo = '64 GB';
          } else {
            storageInfo = '${totalStorageGb.round()} GB';
          }
        }

        // Battery Info
        String batteryUah = results[7].stdout.toString().trim();
        if (batteryUah.isNotEmpty && int.tryParse(batteryUah) != null) {
          int mah = (int.parse(batteryUah) / 1000).round();
          batteryInfo = '${mah}mAh';
        }
      } catch (e) {
        deviceModel = 'Error';
        cpuInfo = 'Error';
        ramInfo = 'Error';
        storageInfo = 'Error';
        batteryInfo = 'Error';
      }
    } else {
      deviceModel = 'Root Required';
      cpuInfo = 'Root Required';
      ramInfo = 'Root Required';
      storageInfo = 'Root Required';
      batteryInfo = 'Root Required';
    }

    if (mounted) {
      setState(() {
        _deviceModel = deviceModel.isEmpty ? 'N/A' : deviceModel;
        _cpuInfo = cpuInfo.isEmpty ? 'N/A' : cpuInfo;
        _ramInfo = ramInfo.isEmpty ? 'N/A' : ramInfo;
        _storageInfo = storageInfo.isEmpty ? 'N/A' : storageInfo;
        _batteryInfo = batteryInfo.isEmpty ? 'N/A' : batteryInfo;
      });
    }
  }

  List<String> _getCredits(AppLocalizations localization) {
    return [
      localization.credits_1,
      localization.credits_2,
      localization.credits_3,
      localization.credits_4,
      localization.credits_5,
      localization.credits_6,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final credits = _getCredits(localization);

    // Define text styles for consistency
    final valueStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final separator = Text(
      '|',
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontSize: 18,
        fontWeight: FontWeight.w200,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Stack(
        fit: StackFit.expand,
        children: [
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
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            child: _isLoading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: LinearProgressIndicator(),
                    ),
                  )
                : AnimatedOpacity(
                    opacity: _isLoading ? 0.0 : 1.0,
                    duration: Duration(milliseconds: 500),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Device spec layout
                          Align(
                            alignment: Alignment.centerRight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(_deviceModel, style: valueStyle),
                                    SizedBox(width: 8),
                                    Text(
                                      localization.device_name,
                                      style: labelStyle,
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 24),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(_cpuInfo, style: valueStyle),
                                    SizedBox(width: 8),
                                    Text(
                                      localization.processor,
                                      style: labelStyle,
                                    ),
                                    SizedBox(width: 8),
                                    separator,
                                  ],
                                ),
                                SizedBox(height: 24),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(_ramInfo, style: valueStyle),
                                    SizedBox(width: 8),
                                    Text(localization.ram, style: labelStyle),
                                    SizedBox(width: 8),
                                    separator,
                                    SizedBox(width: 16),
                                    Text(_storageInfo, style: valueStyle),
                                    SizedBox(width: 8),
                                    Text(
                                      localization.phone_storage,
                                      style: labelStyle,
                                    ),
                                    SizedBox(width: 8),
                                    separator,
                                  ],
                                ),
                                SizedBox(height: 24),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(_batteryInfo, style: valueStyle),
                                    SizedBox(width: 8),
                                    Text(
                                      localization.battery_capacity,
                                      style: labelStyle,
                                    ),
                                    SizedBox(width: 8),
                                    separator,
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // End of device spec layout
                          SizedBox(height: 40),
                          Text(
                            localization.about_title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                          ),
                          SizedBox(height: 15),
                          ...credits.map(
                            (creditText) => Padding(
                              padding: EdgeInsets.symmetric(vertical: 3),
                              child: Text(
                                '• $creditText',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            localization.about_note,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                          SizedBox(height: 20),
                          Center(
                            child: Text(
                              localization.about_quote,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
