// lib/host_screens/list_setup_screen.dart

import 'package:flutter/material.dart';
// Keep Firestore and Auth imports - they are used in _createList
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
// Keep for DateFormat

// Keep for navigation

class ListSetupScreen extends StatefulWidget {
  const ListSetupScreen({Key? key}) : super(key: key);
  @override
  _ListSetupScreenState createState() => _ListSetupScreenState();
}

class _ListSetupScreenState extends State<ListSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _listNameController = TextEditingController();
  // Assuming you switched to address autocomplete, rename if necessary
  final _addressController = TextEditingController();
  final _spotsController = TextEditingController(text: '15');
  final _waitlistController = TextEditingController(text: '0');
  final _bucketController = TextEditingController(text: '0');
  final _stateController = TextEditingController(); // Keep if using manual state entry
  DateTime? _selectedDate;
  bool _isLoading = false;

  // --- Add Address Autocomplete State if using it ---
  String? _selectedAddressDescription;
  String? _selectedStateAbbr;
  // --- End Address State ---


  // --- CORRECTED dispose method ---
  @override
  @mustCallSuper // Add annotation
  void dispose() {
    _listNameController.dispose();
    _addressController.dispose(); // Dispose address controller
    _spotsController.dispose();
    _waitlistController.dispose();
    _bucketController.dispose();
    _stateController.dispose(); // Dispose state controller
    super.dispose(); // REQUIRED: Call super.dispose()
  }
  // --- END CORRECTION ---

  Future<void> _selectDate(BuildContext context) async {
     final DateTime? picked = await showDatePicker(
         context: context,
         initialDate: _selectedDate ?? DateTime.now(),
         firstDate: DateTime.now().subtract(Duration(days: 1)),
         lastDate: DateTime.now().add(Duration(days: 365 * 2)),
     );
     if (picked != null && picked != _selectedDate) {
         setState(() { _selectedDate = picked; });
     }
  }

  Future<void> _createList() async {
     // Add validation for address/state if using autocomplete
     // if (_selectedAddressDescription == null || _selectedStateAbbr == null) { ... return; }
     if (_selectedDate == null) { /* ... Date validation ... */ return; }
     if (!_formKey.currentState!.validate()) return;
     final user = FirebaseAuth.instance.currentUser;
     if (user == null) { /* ... User validation ... */ return; }

     setState(() { _isLoading = true; });
     try {
       final int numberOfSpots = int.tryParse(_spotsController.text) ?? 0;
       final int numberOfWaitlistSpots = int.tryParse(_waitlistController.text) ?? 0;
       final int numberOfBucketSpots = int.tryParse(_bucketController.text) ?? 0;
       // Use state from autocomplete OR manual entry
       final String stateValue = _selectedStateAbbr ?? _stateController.text.trim().toUpperCase();

       final Map<String, dynamic> listData = {
         'listName': _listNameController.text.trim(),
         // Use address from autocomplete OR manual entry
         'address': _selectedAddressDescription ?? _addressController.text.trim(),
         'date': Timestamp.fromDate(_selectedDate!),
         if (stateValue.isNotEmpty) 'state': stateValue,
         'numberOfSpots': numberOfSpots,
         'numberOfWaitlistSpots': numberOfWaitlistSpots,
         'numberOfBucketSpots': numberOfBucketSpots,
         'userId': user.uid,
         'createdAt': Timestamp.now(),
         'spots': {},
         'signedUpUserIds': [],
       };
       await FirebaseFirestore.instance.collection('Lists').add(listData);
       if (mounted) { /* ... success handling ... */ }
     } catch (e) { /* ... error handling ... */ }
     finally { if (mounted) setState(() { _isLoading = false; }); }
  }

  Widget _buildNumberTextField({ required TextEditingController controller, required String label }) {
     return TextFormField( /* ... TextFormField definition ... */ );
  }

  @override
  Widget build(BuildContext context) {
    final Color buttonColor = Colors.blue.shade600;

    return Scaffold(
      appBar: AppBar( /* ... AppBar setup ... */ ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Colors.blue.shade200, Colors.purple.shade100])),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // List Name
              FadeInDown(duration: const Duration(milliseconds: 500), child: TextFormField(controller: _listNameController, /* ... */)),
              const SizedBox(height: 16),
              // Address/Venue Field - Replace this with GooglePlacesAutoCompleteTextField if using
              FadeInDown(duration: const Duration(milliseconds: 600), child: TextFormField(controller: _addressController, decoration: InputDecoration(labelText: 'Address/Venue', /* ... */), /* ... */)),
              const SizedBox(height: 16),
              // Date Picker Tile
              FadeInDown(duration: const Duration(milliseconds: 700), child: Card(child: ListTile(onTap: () => _selectDate(context), /* ... */))),
              const SizedBox(height: 16),
              // State Field (Keep if using manual entry alongside/instead of autocomplete extraction)
              FadeInDown(duration: const Duration(milliseconds: 800), child: TextFormField(controller: _stateController, /* ... */)),
              const SizedBox(height: 24),
              // Spot Number Fields
              FadeInDown(duration: const Duration(milliseconds: 900), child: _buildNumberTextField(controller: _spotsController, label: 'Number of Regular Spots')),
              const SizedBox(height: 16),
              FadeInDown(duration: const Duration(milliseconds: 1000), child: _buildNumberTextField(controller: _waitlistController, label: 'Number of Waitlist Spots')),
              const SizedBox(height: 16),
              FadeInDown(duration: const Duration(milliseconds: 1100), child: _buildNumberTextField(controller: _bucketController, label: 'Number of Bucket Spots')),
              const SizedBox(height: 32),
              // Submit Button
              _isLoading ? Center(child: CircularProgressIndicator(color: buttonColor)) : ElasticIn(child: ElevatedButton(
                onPressed: _createList,
                child: const Text('Save',
                    style: TextStyle(fontSize: 18, color: Colors.white)),
              )),
            ],
          ),
        ),
      ),
    );
  }
}