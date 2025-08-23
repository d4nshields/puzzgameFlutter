import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('Matrix4 operation order verification', () {
    // Test how Matrix4 operations compose
    final m1 = Matrix4.identity()
      ..translate(10.0, 20.0)
      ..scale(2.0, 2.0);
    
    final m2 = Matrix4.identity()
      ..scale(2.0, 2.0)
      ..translate(10.0, 20.0);
    
    final point = Vector3(5.0, 5.0, 0.0);
    
    final result1 = m1.transform3(point);
    final result2 = m2.transform3(point);
    
    print('translate then scale: (${result1.x}, ${result1.y})');
    print('scale then translate: (${result2.x}, ${result2.y})');
    
    // For screen-to-canvas: we want (point - offset) / scale
    // If point = (5,5), offset = (10,20), scale = 2
    // Expected: ((5-10)/2, (5-20)/2) = (-2.5, -7.5)
    
    // Method 1: Create separate matrices and multiply
    final T = Matrix4.translationValues(-10.0, -20.0, 0.0);
    final S = Matrix4.diagonal3Values(0.5, 0.5, 1.0);
    
    // S * T means: first apply T, then apply S
    final combined1 = S.clone()..multiply(T);
    final r1 = combined1.transform3(Vector3(5.0, 5.0, 0.0));
    print('S * T: (${r1.x}, ${r1.y})'); // Should be (-2.5, -7.5)
    
    // T * S means: first apply S, then apply T  
    final combined2 = T.clone()..multiply(S);
    final r2 = combined2.transform3(Vector3(5.0, 5.0, 0.0));
    print('T * S: (${r2.x}, ${r2.y})'); // Should be (-7.5, -17.5)
    
    // Method 2: Build with cascade (operations are post-multiplied)
    final m3 = Matrix4.identity()
      ..translate(-10.0, -20.0)  
      ..scale(0.5, 0.5);
    final r3 = m3.transform3(Vector3(5.0, 5.0, 0.0));
    print('Cascade T then S: (${r3.x}, ${r3.y})');
    
    // The cascade operator post-multiplies, so:
    // m..translate()..scale() builds: I * T * S
    // When applied to vector v: (I * T * S) * v = T * (S * v)
    // This means scale is applied first, then translate!
    
    // So for (screen - offset) / scale, we need the OPPOSITE:
    // We want translate first, then scale
    // But cascade gives us scale first, then translate
    // Therefore we must compensate!
  });
}