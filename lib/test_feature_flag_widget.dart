import 'package:flutter/material.dart';
import 'game_module2/infrastructure/feature_flags.dart';

/// Test widget to verify feature flag system is working
class FeatureFlagTestWidget extends StatefulWidget {
  const FeatureFlagTestWidget({super.key});

  @override
  State<FeatureFlagTestWidget> createState() => _FeatureFlagTestWidgetState();
}

class _FeatureFlagTestWidgetState extends State<FeatureFlagTestWidget> {
  late FeatureFlagService _flagService;
  
  @override
  void initState() {
    super.initState();
    _flagService = FeatureFlagService.instance;
    _flagService.addListener(_onFlagsChanged);
  }
  
  @override
  void dispose() {
    _flagService.removeListener(_onFlagsChanged);
    super.dispose();
  }
  
  void _onFlagsChanged() {
    setState(() {});
  }
  
  @override
  Widget build(BuildContext context) {
    final debugInfo = _flagService.getDebugInfo();
    final samplePuzzleEnabled = _flagService.isEnabled('sample_puzzle');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Flag Test'),
        backgroundColor: _flagService.isUsingLiveData ? Colors.green : Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _flagService.isUsingLiveData 
                    ? Colors.green.shade100 
                    : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _flagService.isUsingLiveData 
                      ? Colors.green 
                      : Colors.orange,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Source: ${debugInfo['currentSource']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Product: ${debugInfo['product']}'),
                  Text('Environment: ${debugInfo['environment']}'),
                  if (debugInfo['lastDatabaseFetch'] != null)
                    Text('Last Update: ${debugInfo['lastDatabaseFetch']}'),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Sample puzzle flag status
            Card(
              child: ListTile(
                title: const Text('Sample Puzzle'),
                subtitle: Text(samplePuzzleEnabled 
                    ? 'ENABLED - Users see sample puzzle' 
                    : 'DISABLED - Users skip to library/registration'),
                trailing: Icon(
                  samplePuzzleEnabled ? Icons.visibility : Icons.visibility_off,
                  color: samplePuzzleEnabled ? Colors.green : Colors.red,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // All flags
            const Text(
              'All Feature Flags:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            
            Expanded(
              child: ListView.builder(
                itemCount: debugInfo['flags'].length,
                itemBuilder: (context, index) {
                  final entries = (debugInfo['flags'] as Map).entries.toList();
                  final flag = entries[index];
                  final isEnabled = _flagService.isEnabled(flag.key);
                  
                  return Card(
                    child: ListTile(
                      title: Text(flag.key),
                      subtitle: Text('Value: ${flag.value}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isEnabled ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isEnabled ? 'ON' : 'OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Refresh button
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _flagService.forceRefresh();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Refreshing flags from database...')),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Force Refresh'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Button to add to your existing UI for quick access to the test
class FeatureFlagTestButton extends StatelessWidget {
  const FeatureFlagTestButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      mini: true,
      backgroundColor: Colors.purple,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FeatureFlagTestWidget(),
          ),
        );
      },
      child: const Icon(Icons.flag, size: 20),
    );
  }
}
