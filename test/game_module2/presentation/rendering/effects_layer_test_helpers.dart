/// Mock implementations for testing the Effects Layer
/// 
/// These mocks allow testing without the full Flame engine initialization

import 'package:flutter/material.dart';
import 'package:puzzgame_flutter/game_module2/presentation/rendering/effects_layer.dart';

/// Mock GameWidget for testing
class MockGameWidget extends StatelessWidget {
  const MockGameWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: const Center(
        child: Text('Mock Game Widget'),
      ),
    );
  }
}

/// Test-friendly version of EffectsLayer that doesn't require Flame
class TestableEffectsLayer extends StatelessWidget {
  final Size size;
  final EffectsController controller;
  final bool debugMode;
  final EffectQualitySettings qualitySettings;

  TestableEffectsLayer({
    super.key,
    required this.size,
    required this.controller,
    this.debugMode = false,
    EffectQualitySettings? qualitySettings,
  }) : qualitySettings = qualitySettings ?? EffectQualitySettings();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Mock game widget
        const MockGameWidget(),
        
        // Debug overlay
        if (debugMode)
          Positioned(
            top: 10,
            left: 10,
            child: _MockDebugOverlay(
              controller: controller,
              qualitySettings: qualitySettings,
            ),
          ),
      ],
    );
  }
}

/// Mock debug overlay for testing
class _MockDebugOverlay extends StatefulWidget {
  final EffectsController controller;
  final EffectQualitySettings qualitySettings;

  const _MockDebugOverlay({
    required this.controller,
    required this.qualitySettings,
  });

  @override
  State<_MockDebugOverlay> createState() => _MockDebugOverlayState();
}

class _MockDebugOverlayState extends State<_MockDebugOverlay> {
  int particleCount = 0;
  int effectCount = 0;
  double fps = 60.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Effects Debug',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Particles: $particleCount',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            'Effects: $effectCount',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            'FPS: ${fps.toStringAsFixed(1)}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            'Quality: ${widget.qualitySettings.currentLevel.name}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  widget.controller.setEffectsEnabled(!widget.controller.effectsEnabled);
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 0),
                ),
                child: Text(
                  widget.controller.effectsEnabled ? 'Disable' : 'Enable',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Test helper to verify effect triggering
class EffectRecorder {
  final List<EffectDefinition> recordedEffects = [];

  void recordEffect(EffectDefinition effect) {
    recordedEffects.add(effect);
  }

  void clear() {
    recordedEffects.clear();
  }

  bool hasEffect(EffectType type) {
    return recordedEffects.any((e) => e.type == type);
  }

  int countEffects(EffectType type) {
    return recordedEffects.where((e) => e.type == type).length;
  }
}

/// Extension to help with testing
extension EffectsControllerTestExtensions on EffectsController {
  /// Create a test controller with recording capability
  static EffectsController createTestController() {
    return EffectsController();
  }
}
