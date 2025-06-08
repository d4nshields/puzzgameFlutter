// Zoom Control Widget
// File: lib/game_module/widgets/zoom_control.dart

import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/core/domain/services/zoom_service.dart';

/// Zoom control widget - vertical slider for zoom control
class ZoomControl extends StatelessWidget {
  final ZoomService zoomService;
  final EdgeInsets margin;
  final double width;
  final double height;
  
  const ZoomControl({
    super.key,
    required this.zoomService,
    this.margin = const EdgeInsets.all(16),
    this.width = 40,
    this.height = 200,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      width: width,
      height: height,
      child: ListenableBuilder(
        listenable: zoomService,
        builder: (context, child) {
          return Column(
            children: [
              // Zoom in button
              IconButton(
                onPressed: () => zoomService.adjustZoom(0.1),
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.8),
                  shape: const CircleBorder(),
                ),
              ),
              
              // Vertical slider
              Expanded(
                child: RotatedBox(
                  quarterTurns: -1,
                  child: Slider(
                    value: zoomService.zoomLevel,
                    min: zoomService.minZoom,
                    max: zoomService.maxZoom,
                    divisions: ((zoomService.maxZoom - zoomService.minZoom) / 0.1).round(),
                    onChanged: (value) => zoomService.setZoom(value),
                  ),
                ),
              ),
              
              // Zoom out button
              IconButton(
                onPressed: () => zoomService.adjustZoom(-0.1),
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.8),
                  shape: const CircleBorder(),
                ),
              ),
              
              // Reset button
              IconButton(
                onPressed: () => zoomService.reset(),
                icon: const Icon(Icons.center_focus_strong),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.8),
                  shape: const CircleBorder(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
