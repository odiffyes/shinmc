import 'package:material_ui/material_ui.dart';

import 'core/theme.dart';
import 'features/calendar/calendar_screen.dart';

class ShinmcApp extends StatelessWidget {
  const ShinmcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '주기',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const CalendarScreen(),
    );
  }
}
