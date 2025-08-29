/// Debug tracer for game_module2 to understand what's actually running
class DebugTracer {
  static final List<String> _logs = [];
  static bool enabled = true;
  
  static void log(String component, String message, {dynamic data}) {
    if (!enabled) return;
    
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] [$component] $message';
    
    _logs.add(logLine);
    
    // Print with distinctive formatting
    print('🔍 DEBUG: $logLine');
    if (data != null) {
      print('   📊 DATA: $data');
    }
  }
  
  static void logMagnetic(String message, {dynamic data}) {
    log('MAGNETIC', message, data: data);
  }
  
  static void logInteraction(String message, {dynamic data}) {
    log('INTERACTION', message, data: data);
  }
  
  static void logWorkspace(String message, {dynamic data}) {
    log('WORKSPACE', message, data: data);
  }
  
  static void logStateMachine(String message, {dynamic data}) {
    log('STATE_MACHINE', message, data: data);
  }
  
  static void logWidget(String message, {dynamic data}) {
    log('WIDGET', message, data: data);
  }
  
  static void logFeatureFlag(String message, {dynamic data}) {
    log('FEATURE_FLAG', message, data: data);
  }
  
  static void dumpLogs() {
    print('=' * 80);
    print('DEBUG TRACE DUMP - Total logs: ${_logs.length}');
    print('=' * 80);
    for (final log in _logs) {
      print(log);
    }
    print('=' * 80);
  }
  
  static void clear() {
    _logs.clear();
  }
}
