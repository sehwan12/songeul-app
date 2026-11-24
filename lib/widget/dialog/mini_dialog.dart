import 'package:aiwriting_collection/design_system/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:aiwriting_collection/generated/app_localizations.dart';

class MiniDialog extends StatelessWidget {
  final double scale;
  final String title;
  final String content;
  const MiniDialog({
    super.key,
    required this.scale,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLocalizations = AppLocalizations.of(context)!;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.dialog * scale),
      ),
      backgroundColor: Colors.white,
      title: Center(
        child: Text(
          title,
          style: TextStyle(
            color: Colors.green,
            fontFamily: AppFonts.interface,
            fontSize: 20 * scale,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      content: Text(
        content,

        style: TextStyle(
          color: AppColors.text,
          fontFamily: AppFonts.interface,
          fontSize: 15 * scale,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.medium * scale,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(6.0),
            child: Text(
              appLocalizations.ok,
              style: TextStyle(
                color: Colors.red.shade400,
                fontFamily: AppFonts.interface,
                fontSize: 13 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
