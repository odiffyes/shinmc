import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';

/// External calendar settings (§9.1). Toggles are placeholders until the
/// stage-5 integrations exist; they are disabled so nothing is implied.
class CalendarSettingsScreen extends StatelessWidget {
  const CalendarSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final deviceLabel = defaultTargetPlatform == TargetPlatform.iOS
        ? 'iOS 캘린더'
        : 'Android 캘린더';
    return Scaffold(
      appBar: AppBar(title: const Text('캘린더 연동')),
      body: ListView(
        children: [
          const SwitchListTile(
            title: Text('Google Calendar'),
            value: false,
            onChanged: null,
          ),
          SwitchListTile(
            title: Text(deviceLabel),
            value: false,
            onChanged: null,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '캘린더 연동은 준비 중이에요.\n'
              '연동하면 생리 예정일이 해당 캘린더 서비스에 저장됩니다.',
              style: TextStyle(color: AppColors.secondaryText, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
