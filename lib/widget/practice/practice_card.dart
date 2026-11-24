import 'package:aiwriting_collection/design_system/app_layout.dart';
import 'package:aiwriting_collection/design_system/app_tokens.dart';
import 'package:flutter/material.dart';

class PracticeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final VoidCallback onTap;

  //기본 기준값
  final double basePortrait;
  final double baseLandscape;

  //원한다면 카드의 너비-높이-폰트크기를 직접 지정
  final double? cardWidth;
  final double? cardHeight;
  final double? fontSize;
  final double? semiFontSize;
  final double? imageScale;

  const PracticeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.onTap,
    this.basePortrait = AppLayout.portraitReferenceWidth,
    this.baseLandscape = AppLayout.landscapeReferenceHeight,

    this.cardWidth,
    this.cardHeight,
    this.fontSize,
    this.semiFontSize,
    this.imageScale,
  });

  double scaled(BuildContext context, double value) {
    // 만약 cardWidth, cardHeight가 지정되었다면 그 값을 사용
    final Size size =
        (cardWidth != null && cardHeight != null)
            ? Size(cardWidth!, cardHeight!)
            : MediaQuery.of(context).size;
    return value *
        AppLayout.scale(
          size,
          portraitWidth: basePortrait,
          landscapeHeight: baseLandscape,
        );
  }

  @override
  Widget build(BuildContext context) {
    final double paddingH = scaled(context, AppSpacing.medium);
    final double spacing = scaled(context, AppSpacing.small);

    final bool isLandscape =
        (cardWidth ?? MediaQuery.of(context).size.width) >
        (cardHeight ?? MediaQuery.of(context).size.height);
    final titleFontSize = scaled(context, fontSize ?? (isLandscape ? 28 : 20));
    final subtitleFontSize = scaled(
      context,
      semiFontSize ?? (isLandscape ? 20 : 13),
    );
    final imageSizeAdjusted = scaled(
      context,
      imageScale ?? (isLandscape ? 110 : 70),
    );

    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: paddingH,
          vertical: scaled(context, 5),
        ),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: paddingH,
              vertical: paddingH,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                scaled(context, AppRadius.card),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, scaled(context, 2)),
                  blurRadius: scaled(context, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      SizedBox(height: spacing),
                      Flexible(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: AppFonts.reading,
                            fontSize: subtitleFontSize,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (imagePath.isNotEmpty)
                  Image.asset(
                    imagePath,
                    width: imageSizeAdjusted,
                    height: imageSizeAdjusted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
