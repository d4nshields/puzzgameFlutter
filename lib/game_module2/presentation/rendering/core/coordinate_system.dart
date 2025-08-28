part of '../hybrid_renderer.dart';

/// Manages coordinate system transformations between different spaces
class CoordinateSystem {
  Size _screenSize;
  final Size gameSize;
  
  // Transformation matrices
  Matrix4 _screenToCanvas = Matrix4.identity();
  Matrix4 _canvasToGrid = Matrix4.identity();
  Matrix4 _gridToWorkspace = Matrix4.identity();
  
  // Cached inverse matrices
  Matrix4 _canvasToScreen = Matrix4.identity();
  Matrix4 _gridToCanvas = Matrix4.identity();
  Matrix4 _workspaceToGrid = Matrix4.identity();

  CoordinateSystem({
    required Size screenSize,
    required this.gameSize,
  }) : _screenSize = screenSize {
    _updateTransformations();
  }

  void updateScreenSize(Size newSize) {
    if (_screenSize != newSize) {
      _screenSize = newSize;
      _updateTransformations();
    }
  }

  void _updateTransformations() {
    // Calculate scale factor to fit game within screen
    final scaleX = _screenSize.width / gameSize.width;
    final scaleY = _screenSize.height / gameSize.height;
    final scale = math.min(scaleX, scaleY);
    
    // Center the game area on screen
    final offsetX = (_screenSize.width - gameSize.width * scale) / 2;
    final offsetY = (_screenSize.height - gameSize.height * scale) / 2;
    
    // Build transformation matrices
    // We want: canvas = (screen - offset) / scale
    // Using Matrix4's cascade operator, we must create S^-1 * T^-1
    // where operations are in mathematical order (right to left application)
    
    // Method: Create the matrices separately and multiply in correct order
    final translationMatrix = Matrix4.translationValues(-offsetX, -offsetY, 0);
    final scaleMatrix = Matrix4.diagonal3Values(1 / scale, 1 / scale, 1.0);
    
    // For (screen - offset) / scale, we need: scale * translation
    _screenToCanvas = scaleMatrix.clone()..multiply(translationMatrix);
    
    _canvasToGrid = Matrix4.identity()
      ..scale(1 / 50.0); // 50 pixels per grid unit
    
    _gridToWorkspace = Matrix4.identity(); // Identity for now
    
    // Calculate inverse matrices
    _canvasToScreen = Matrix4.identity()..setFrom(_screenToCanvas)..invert();
    _gridToCanvas = Matrix4.identity()..setFrom(_canvasToGrid)..invert();
    _workspaceToGrid = Matrix4.identity()..setFrom(_gridToWorkspace)..invert();
  }

  // Screen to Canvas transformations
  Offset screenToCanvas(Offset screenPoint) {
    final vector = vector_math.Vector3(screenPoint.dx, screenPoint.dy, 0);
    final transformed = _screenToCanvas.transform3(vector);
    return Offset(transformed.x, transformed.y);
  }

  Offset canvasToScreen(Offset canvasPoint) {
    final vector = vector_math.Vector3(canvasPoint.dx, canvasPoint.dy, 0);
    final transformed = _canvasToScreen.transform3(vector);
    return Offset(transformed.x, transformed.y);
  }

  // Canvas to Grid transformations
  Offset canvasToGrid(Offset canvasPoint) {
    final vector = vector_math.Vector3(canvasPoint.dx, canvasPoint.dy, 0);
    final transformed = _canvasToGrid.transform3(vector);
    return Offset(transformed.x, transformed.y);
  }

  Offset gridToCanvas(Offset gridPoint) {
    final vector = vector_math.Vector3(gridPoint.dx, gridPoint.dy, 0);
    final transformed = _gridToCanvas.transform3(vector);
    return Offset(transformed.x, transformed.y);
  }

  // Grid to Workspace transformations
  Offset gridToWorkspace(Offset gridPoint) {
    final vector = vector_math.Vector3(gridPoint.dx, gridPoint.dy, 0);
    final transformed = _gridToWorkspace.transform3(vector);
    return Offset(transformed.x, transformed.y);
  }

  Offset workspaceToGrid(Offset workspacePoint) {
    final vector = vector_math.Vector3(workspacePoint.dx, workspacePoint.dy, 0);
    final transformed = _workspaceToGrid.transform3(vector);
    return Offset(transformed.x, transformed.y);
  }

  // Combined transformations
  Offset screenToWorkspace(Offset screenPoint) {
    final canvasPoint = screenToCanvas(screenPoint);
    final gridPoint = canvasToGrid(canvasPoint);
    return gridToWorkspace(gridPoint);
  }

  Offset workspaceToScreen(Offset workspacePoint) {
    final gridPoint = workspaceToGrid(workspacePoint);
    final canvasPoint = gridToCanvas(gridPoint);
    return canvasToScreen(canvasPoint);
  }

  // Transform rectangles
  Rect transformRect(Rect rect, Matrix4 transform) {
    final topLeft = _transformPoint(rect.topLeft, transform);
    final topRight = _transformPoint(rect.topRight, transform);
    final bottomLeft = _transformPoint(rect.bottomLeft, transform);
    final bottomRight = _transformPoint(rect.bottomRight, transform);
    
    final minX = [topLeft.dx, topRight.dx, bottomLeft.dx, bottomRight.dx].reduce(math.min);
    final maxX = [topLeft.dx, topRight.dx, bottomLeft.dx, bottomRight.dx].reduce(math.max);
    final minY = [topLeft.dy, topRight.dy, bottomLeft.dy, bottomRight.dy].reduce(math.min);
    final maxY = [topLeft.dy, topRight.dy, bottomLeft.dy, bottomRight.dy].reduce(math.max);
    
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Offset _transformPoint(Offset point, Matrix4 transform) {
    final vector = vector_math.Vector3(point.dx, point.dy, 0);
    final transformed = transform.transform3(vector);
    return Offset(transformed.x, transformed.y);
  }

  // Get visible bounds in different coordinate spaces
  Rect get screenBounds => Offset.zero & _screenSize;
  
  Rect get canvasBounds {
    final topLeft = screenToCanvas(Offset.zero);
    final bottomRight = screenToCanvas(Offset(_screenSize.width, _screenSize.height));
    return Rect.fromPoints(topLeft, bottomRight);
  }
  
  Rect get gridBounds {
    final canvasBounds = this.canvasBounds;
    final topLeft = canvasToGrid(canvasBounds.topLeft);
    final bottomRight = canvasToGrid(canvasBounds.bottomRight);
    return Rect.fromPoints(topLeft, bottomRight);
  }
}