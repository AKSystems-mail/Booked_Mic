// lib/host_screens/edit_list_screen.dart

import 'package:flutter/material.dart';
// Removed unnecessary import: import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Keep for Timestamp
// Removed unused import: import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart'; // Keep for DateFormat
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/firestore_provider.dart';
import 'package:myapp/models/show.dart'; // Import Show model

class EditListScreen extends StatefulWidget {
  final String listId;
  const EditListScreen({super.key, required this.listId});

  @override
  State<EditListScreen> createState() => _EditListScreenState();
}

class _EditListScreenState extends State<EditListScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _listNameController;
  late TextEditingController _spotsController;
  late TextEditingController _waitlistController;
  late TextEditingController _bucketController;
  late TextEditingController _addressController;

  String? _selectedAddressDescription;
  String? _selectedStateAbbr;
  double? _selectedLat;
  double? _selectedLng;

  DateTime? _selectedDate;
  bool _isLoading = true;
  bool _isSaving = false;

  final String googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'MISSING_API_KEY';

  @override
  void initState() { /* ... */ }

  @override
  @mustCallSuper
  void dispose() { /* ... dispose controllers ... super.dispose(); */ }

  Future<void> _fetchListData() async { /* ... */ }

  // Keep _selectDate - used by DatePicker ListTile
  Future<void> _selectDate(BuildContext context) async {
     final DateTime? picked = await showDatePicker(
         context: context, // Added context
         initialDate: _selectedDate ?? DateTime.now(),
         firstDate: DateTime.now().subtract(Duration(days: 30)), // Added firstDate
         lastDate: DateTime.now().add(Duration(days: 365 * 2)), // Added lastDate
     );
     if (picked != null && picked != _selectedDate) {
         setState(() { _selectedDate = picked; });
     }
  }

  // Keep _extractStateAbbr - used by Autocomplete callback
  String? _extractStateAbbr(Prediction prediction) {
     // ... (extraction logic) ...
     return null; // Added return
  }

  // --- CORRECTED _updateList ---
  Future<void> _updateList() async {
    if (_selectedAddressDescription == null || _selectedAddressDescription!.isEmpty || _selectedStateAbbr == null || _selectedStateAbbr!.isEmpty) { /* ... Address validation ... */ return; }
    if (_selectedDate == null) { /* ... Date validation ... */ return; }
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isSaving = true; });
    try {
      final int numberOfSpots = int.tryParse(_spotsController.text) ?? 0;
      final int numberOfWaitlistSpots = int.tryParse(_waitlistController.text) ?? 0;
      final int numberOfBucketSpots = int.tryParse(_bucketController.text) ?? 0;

      // Prepare update map directly
      final Map<String, dynamic> updatedData = {
        'listName': _listNameController.text.trim(),
        'address': _selectedAddressDescription!,
        'state': _selectedStateAbbr!,
        'latitude': _selectedLat,
        'longitude': _selectedLng,
        'date': Timestamp.fromDate(_selectedDate!),
        'numberOfSpots': numberOfSpots,
        'numberOfWaitlistSpots': numberOfWaitlistSpots,
        'numberOfBucketSpots': numberOfBucketSpots,
      };

      // Modify updateShow in Provider/Service to accept Map<String, dynamic>
      await context.read<FirestoreProvider>().updateShowMap(widget.listId, updatedData);

      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('List updated successfully!'))); Navigator.pop(context); }
    } catch (e) { /* ... Error handling ... */ }
    finally { if (mounted) setState(() { _isSaving = false; }); }
  }
  // --- END CORRECTION ---

  Widget _buildNumberTextField({ required TextEditingController controller, required String label }) {
     return TextFormField( /* ... TextFormField definition ... */ );
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color buttonColor = Colors.blue.shade600;
    // Removed unused labelColor

    Widget bodyContent;
    if (googleApiKey == 'MISSING_API_KEY') { /* ... Error Message ... */ }
    else { bodyContent = Form( /* ... Form UI ... */ ); }

    return Scaffold( /* ... Scaffold UI ... */ );
  }
}

// --- REMOVED Dummy DocumentSnapshot ---