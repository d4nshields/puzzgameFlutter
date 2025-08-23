// Test hybrid renderer compilation
import '../hybrid_renderer.dart';
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // This file tests if the hybrid renderer compiles correctly
    return Container();
  }
}

// Test that classes are accessible
void testClasses() {
  final config = RenderingConfig();
  final quality = QualityLevel.high;
  print('Config: $config, Quality: $quality');
}
