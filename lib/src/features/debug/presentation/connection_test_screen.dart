import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../config/firestore_config.dart';

class ConnectionTestScreen extends StatefulWidget {
  const ConnectionTestScreen({super.key});

  @override
  State<ConnectionTestScreen> createState() => _ConnectionTestScreenState();
}

class _ConnectionTestScreenState extends State<ConnectionTestScreen> {
  String _status = 'Idle';
  Color _statusColor = Colors.grey;

  Future<void> _testConnection() async {
    setState(() {
      _status = 'Testing connection to Firestore...';
      _statusColor = Colors.orange;
    });

    try {
      final db = FirestoreConfig.instanceOrNull;
      if (db == null) {
        throw 'Firestore instance is null (Configuration error?)';
      }

      final dbId = db.databaseId;
      final projectId = db.app.options.projectId;

      // Write test
      final docRef = db.collection('test').doc('connectivity');
      await docRef.set({
        'timestamp': FieldValue.serverTimestamp(),
        'test': 'connection_check',
      });

      // Read test
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        throw 'Write succeeded but document not found (Rules issue?)';
      }

      setState(() {
        _status = 'SUCCESS!\n\nConnected to:\nProject: $projectId\nDatabase: $dbId\n\nRead & Write operations confirmed.';
        _statusColor = Colors.green;
      });
    } catch (e) {
      setState(() {
        _status = 'FAILURE\n\nError: $e';
        _statusColor = Colors.red;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Test'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _statusColor),
                ),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _testConnection,
                icon: const Icon(Icons.network_check),
                label: const Text('Run Connection Test'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
