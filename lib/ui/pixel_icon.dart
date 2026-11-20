import 'package:material_ui/material_ui.dart';

// Each row is an eight-pixel bitmap, drawn without antialiasing.
enum PixelGlyph {
  keys([255, 165, 165, 165, 165, 153, 153, 255]),
  loop([0, 62, 67, 135, 225, 194, 124, 0]),
  wheel([60, 66, 153, 165, 165, 153, 66, 60]),
  mic([24, 60, 60, 60, 129, 66, 60, 24]),
  stop([0, 126, 126, 126, 126, 126, 126, 0]),
  sliders([16, 255, 16, 0, 4, 255, 4, 0]),
  pin([60, 60, 24, 60, 126, 24, 24, 16]),
  close([0, 66, 36, 24, 24, 36, 66, 0]),
  center([195, 129, 0, 24, 24, 0, 129, 195]),
  left([0, 8, 16, 32, 32, 16, 8, 0]),
  right([0, 16, 8, 4, 4, 8, 16, 0]),
  down([0, 0, 126, 60, 24, 0, 0, 0]);

  const PixelGlyph(this.rows);
  final List<int> rows;
}

class PixelIcon extends StatelessWidget {
  const PixelIcon(this.glyph, {super.key, this.size = 20, this.color});
  final PixelGlyph glyph;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _Pixels(
      glyph,
      color ?? IconTheme.of(context).color ?? Colors.white,
    ),
  );
}

class _Pixels extends CustomPainter {
  const _Pixels(this.glyph, this.color);
  final PixelGlyph glyph;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 8;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        if ((glyph.rows[y] & (128 >> x)) != 0) {
          canvas.drawRect(Rect.fromLTWH(x * unit, y * unit, unit, unit), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Pixels old) => old.color != color || old.glyph != glyph;
}
