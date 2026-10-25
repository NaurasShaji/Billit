import 'package:flutter/material.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup started...')),
                );
              },
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Backup Data'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Restore started...')),
                );
              },
              icon: const Icon(Icons.cloud_download),
              label: const Text('Restore Data'),
            ),
          ],
        ),
      ),
    );
  }
}
