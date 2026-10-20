// lib/widgets/version_footer.dart

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionFooter extends StatefulWidget {
  const VersionFooter({super.key});

  @override
  State<VersionFooter> createState() => _VersionFooterState();
}

class _VersionFooterState extends State<VersionFooter> {
  String _version = 'Yükleniyor...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _version = 'v${packageInfo.version}';
      });
    } catch (e) {
      setState(() {
        _version = 'Yüklenemedi';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
      ),
      child: Center(
        child: Text(
          'EVOM SPOR $_version',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
