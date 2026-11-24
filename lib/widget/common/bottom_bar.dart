import 'package:aiwriting_collection/design_system/app_layout.dart';
import 'package:aiwriting_collection/design_system/app_tokens.dart';
import 'package:aiwriting_collection/generated/app_localizations.dart';
import 'package:flutter/material.dart';

class Bottom extends StatelessWidget {
  const Bottom({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scale = AppLayout.scale(MediaQuery.sizeOf(context));
    final barHeight = 65.0 * scale;
    final labelStyle = TextStyle(
      fontSize: barHeight * 0.22,
      color: AppColors.text,
      fontWeight: FontWeight.bold,
    );

    Tab tab(IconData icon, String label) {
      return Tab(
        icon: Icon(icon, size: barHeight * 0.40),
        child: Text(label, style: labelStyle),
      );
    }

    return SizedBox(
      height: barHeight,
      child: ColoredBox(
        color: AppColors.primary,
        child: TabBar(
          labelColor: AppColors.navigationSelected,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.transparent,
          tabs: [
            tab(Icons.home, l10n.home),
            tab(Icons.school, l10n.freeStudy),
            tab(Icons.history, l10n.history),
            tab(Icons.person, l10n.myInfo),
          ],
        ),
      ),
    );
  }
}
