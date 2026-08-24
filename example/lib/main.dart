import 'package:flutter/material.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Idura Verify')),
        body: const Center(
          child: Text('The login screen arrives with phase 6.'),
        ),
      ),
    );
  }
}
