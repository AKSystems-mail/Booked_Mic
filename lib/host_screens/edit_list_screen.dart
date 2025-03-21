import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'qr_code_screen.dart';

class EditListScreen extends StatefulWidget {
  final String showId;

  const EditListScreen({super.key, required this.showId});

  @override
  _EditListScreenState createState() => _EditListScreenState();
}

class _EditListScreenState extends State<EditListScreen> {
  final _formKey = GlobalKey<FormState>();
  DocumentSnapshot? showData;

  @override
  void initState() {
    super.initState();
    _loadShowData();
  }

  void _loadShowData() async {
    showData = await FirebaseFirestore.instance.collection('shows').doc(widget.showId).get();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (showData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Show')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Show')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              initialValue: showData!['showName'],
              decoration: const InputDecoration(labelText: 'Show Name'),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter a show name';
                }
                return null;
              },
              onSaved: (value) {
                showData!.reference.update({'showName': value});
              },
            ),
            // Add more input fields for other show details
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  _formKey.currentState?.save();
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => QRCodeScreen(showId: widget.showId)),
                );
              },
              child: const Text('Generate New QR Code'),
            ),
          ],
        ),
      ),
    );
  }
}