import 'package:flutter/material.dart';

/// Full logo: dumbbell mark and the FitCenter name, with no box behind it.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.width = 240});

  final double width;

  @override
  Widget build(BuildContext context) => Image.asset(
    // "Fit" is white on dark screens and green on light ones.
    Theme.of(context).brightness == Brightness.dark
        ? 'assets/images/logo.png'
        : 'assets/images/logo_light.png',
    width: width,
    filterQuality: FilterQuality.high,
    semanticLabel: 'FitCenter',
  );
}

/// The dumbbell mark only, for small spaces.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Image.asset(
      'assets/images/logo_mark.png',
      filterQuality: FilterQuality.high,
      semanticLabel: 'Logo FitCenter',
    ),
  );
}
