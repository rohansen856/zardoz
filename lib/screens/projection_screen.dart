import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/cast_service.dart';
import '../widgets/cast_sheet.dart';

/// Fullscreen projection mode for projecting embroidery designs onto fabric.
/// Supports zoom, pan, rotation, opacity control, color inversion, and grid overlay.
class ProjectionScreen extends StatefulWidget {
  final String imageUrl;
  final String title;

  const ProjectionScreen({super.key, required this.imageUrl, required this.title});

  @override
  State<ProjectionScreen> createState() => _ProjectionScreenState();
}

class _ProjectionScreenState extends State<ProjectionScreen> {
  bool _controlsVisible = true;
  double _opacity = 1.0;
  double _rotation = 0.0;
  bool _invertColors = false;
  bool _showGrid = false;
  bool _mirrorH = false;
  final _transformCtl = TransformationController();
  final _cast = CastService();

  @override
  void initState() {
    super.initState();
    _cast.addListener(_onCastChanged);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _autoHideControls();
  }

  @override
  void dispose() {
    _cast.removeListener(_onCastChanged);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _transformCtl.dispose();
    super.dispose();
  }

  void _onCastChanged() {
    if (mounted) setState(() {});
  }

  void _autoHideControls() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _controlsVisible) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _autoHideControls();
  }

  void _reset() {
    _transformCtl.value = Matrix4.identity();
    setState(() {
      _rotation = 0;
      _opacity = 1;
      _invertColors = false;
      _showGrid = false;
      _mirrorH = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_showGrid) CustomPaint(painter: _GridPainter()),

            // Design image
            Center(
              child: InteractiveViewer(
                transformationController: _transformCtl,
                minScale: 0.05,
                maxScale: 15.0,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationZ(_rotation * pi / 180)
                    ..multiply(Matrix4.diagonal3Values(
                        _mirrorH ? -1.0 : 1.0, 1.0, 1.0)),
                  child: Opacity(
                    opacity: _opacity,
                    child: ColorFiltered(
                      colorFilter: _invertColors
                          ? const ColorFilter.matrix(<double>[
                              -1, 0, 0, 0, 255,
                              0, -1, 0, 0, 255,
                              0, 0, -1, 0, 255,
                              0, 0, 0, 1, 0,
                            ])
                          : const ColorFilter.mode(
                              Colors.transparent, BlendMode.multiply),
                      child: CachedNetworkImage(
                        imageUrl: widget.imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error, color: Colors.red, size: 64),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Controls overlay
            if (_controlsVisible) ...[
              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 26),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _cast.isCasting ? Icons.cast_connected : Icons.cast,
                            color: _cast.isCasting ? Colors.greenAccent : Colors.white70,
                          ),
                          tooltip: _cast.isCasting ? 'Casting' : 'Cast to projector',
                          onPressed: () => showCastSheet(context, widget.imageUrl),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white70),
                          tooltip: 'Reset all',
                          onPressed: _reset,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom controls
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Opacity
                        _SliderRow(
                          icon: Icons.opacity,
                          label: 'Opacity',
                          value: _opacity,
                          suffix: '${(_opacity * 100).round()}%',
                          onChanged: (v) => setState(() => _opacity = v),
                        ),

                        // Rotation
                        _SliderRow(
                          icon: Icons.rotate_right,
                          label: 'Rotate',
                          value: _rotation,
                          min: -180,
                          max: 180,
                          suffix: '${_rotation.round()}°',
                          onChanged: (v) => setState(() => _rotation = v),
                        ),

                        const SizedBox(height: 8),

                        // Toggle buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ToggleBtn(
                              icon: Icons.invert_colors,
                              label: 'Invert',
                              active: _invertColors,
                              onTap: () =>
                                  setState(() => _invertColors = !_invertColors),
                            ),
                            _ToggleBtn(
                              icon: Icons.grid_on,
                              label: 'Grid',
                              active: _showGrid,
                              onTap: () => setState(() => _showGrid = !_showGrid),
                            ),
                            _ToggleBtn(
                              icon: Icons.flip,
                              label: 'Mirror',
                              active: _mirrorH,
                              onTap: () => setState(() => _mirrorH = !_mirrorH),
                            ),
                            _ToggleBtn(
                              icon: Icons.rotate_left,
                              label: '-90°',
                              onTap: () => setState(() => _rotation -= 90),
                            ),
                            _ToggleBtn(
                              icon: Icons.rotate_right,
                              label: '+90°',
                              onTap: () => setState(() => _rotation += 90),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    this.min = 0,
    this.max = 1,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 6),
        SizedBox(
          width: 52,
          child: Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(suffix,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
              textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active ? Colors.white24 : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white30),
            ),
            child: Icon(icon,
                color: active ? Colors.white : Colors.white70, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid overlay painter
// ---------------------------------------------------------------------------

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0x26FFFFFF)
      ..strokeWidth = 0.5;

    const spacing = 50.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final centerPaint = Paint()
      ..color = const Color(0x66FF0000)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(size.width / 2, size.height), centerPaint);
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
