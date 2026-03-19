import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

class PerformanceScreen extends ConsumerStatefulWidget {
  final int setlistId;

  const PerformanceScreen({super.key, required this.setlistId});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  @override
  void initState() {
    super.initState();
    // Keep screen on during performance
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_note, size: 80, color: Colors.white),
              const SizedBox(height: 16),
              const Text('Modalità Performance',
                  style: TextStyle(color: Colors.white, fontSize: 24)),
              const SizedBox(height: 8),
              Text('Setlist ID: ${widget.setlistId}',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              const Text('Implementazione completa — Fase 2',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
