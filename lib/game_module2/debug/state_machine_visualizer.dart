import 'package:flutter/material.dart';
import '../domain/services/piece_state_machine.dart';

/// Debug panel for visualizing state machine states
class StateMachineDebugPanel extends StatelessWidget {
  final Map<String, PieceStateMachine> stateMachines;
  
  const StateMachineDebugPanel({
    super.key,
    required this.stateMachines,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'State Machines',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...stateMachines.entries.map((entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Text(
                  '${entry.key}: ',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  entry.value.currentState.toString().split('.').last,
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
