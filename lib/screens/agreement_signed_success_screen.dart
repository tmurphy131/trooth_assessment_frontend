import 'package:flutter/material.dart';

class AgreementSignedSuccessScreen extends StatelessWidget {
  const AgreementSignedSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        title: const Text('Signed Successfully', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Card(
          color: Colors.grey[850],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 72),
                const SizedBox(height: 16),
                const Text('Thank you for signing!', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Your mentorship agreement has been submitted.',
                  style: TextStyle(color: Colors.grey[300], fontFamily: 'Poppins'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
