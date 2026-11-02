import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/landmark_providers.dart';

/// Temporary screen to verify the API connection is working.
/// Shows landmarks in a ListView with a connection status indicator.
/// Remove or replace this with the real home screen in a later step.
class ApiTestScreen extends ConsumerWidget {
  const ApiTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landmarksAsync = ref.watch(landmarkListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DaanAR API Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(landmarkListProvider),
          ),
        ],
      ),
      body: landmarksAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to DaanAR API...'),
            ],
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  '❌ API Connection Failed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Make sure the Laravel server is running:\n'
                  'php -S 127.0.0.1:8000 server.php\n\n'
                  'And the emulator can reach it via 10.0.2.2:8000',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        data: (result) => Column(
          children: [
            // Connection success banner
            Container(
              width: double.infinity,
              color: Colors.green.shade100,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    '✅ API Connected ${result.landmarks.length} landmarks loaded',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: result.landmarks.length,
                itemBuilder: (context, index) {
                  final l = result.landmarks[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.brown.shade200,
                        child: Text(
                          l.category[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        l.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${l.municipality?.name ?? 'Unknown'} · ${l.category}',
                      ),
                      trailing: l.isFeatured
                          ? const Icon(Icons.star, color: Colors.amber)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
