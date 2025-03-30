// lib/host_screens/edit_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart'; // Keep for DateFormat
// Removed google_places_flutter imports as they weren't used in the provided snippet
// If you ARE using Google Places Autocomplete here, re-add:
// import 'package:google_places_flutter/google_places_flutter.dart';
// import 'package:google_places_flutter/model/prediction.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';

class EditListScreen extends StatefulWidget {
  final String listId;
  const EditListScreen({Key? key, required this.listId}) : super(key: key);

  @override
  _EditListScreenState createState() => _EditListScreenState();
}

class _EditListScreenState extends State<EditListScreen> {
  // ... (formKey, firestore, auth) ...
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;


  // Controllers
  late TextEditingController _listNameController;
  late TextEditingController _venueNameController; // Keep if using for address/venue
  late TextEditingController _spotsController;
  late TextEditingController _waitlistController;
  late TextEditingController _bucketController;
  late TextEditingController _stateController;

  DateTime? _selectedDate;
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _initialData;

  // final String googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'MISSING_API_KEY'; // Keep if using Places

  @override
  void initState() {
    super.initState();
    _listNameController = TextEditingController();
    _venueNameController = TextEditingController(); // Keep if using
    _spotsController = TextEditingController();
    _waitlistController = TextEditingController();
    _bucketController = TextEditingController();
    _stateController = TextEditingController();
    _fetchListData();
  }

  @override
  void dispose() {
    _listNameController.dispose();
    _venueNameController.dispose(); // Keep if using
    _spotsController.dispose();
    _waitlistController.dispose();
    _bucketController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _fetchListData() async {
    setState(() { _isLoading = true; });
    try {
      final docSnap = await _firestore.collection('Lists').doc(widget.listId).get();
      if (docSnap.exists && mounted) {
        _initialData = docSnap.data();
        _listNameController.text = _initialData?['listName'] ?? '';
        _venueNameController.text = _initialData?['venueName'] ?? _initialData?['address'] ?? ''; // Load venue or address
        _spotsController.text = (_initialData?['numberOfSpots'] ?? 0).toString();
        _waitlistController.text = (_initialData?['numberOfWaitlistSpots'] ?? 0).toString();
        _bucketController.text = (_initialData?['numberOfBucketSpots'] ?? 0).toString();
        _stateController.text = _initialData?['state'] ?? '';
        final Timestamp? dateTimestamp = _initialData?['date'] as Timestamp?;
        _selectedDate = dateTimestamp?.toDate();
      } else { /* ... Handle list not found ... */ }
    } catch (e) { /* ... Handle error ... */ }
    finally { if (mounted) setState(() { _isLoading = false; }); }
  }

  // This function IS used by the Date Picker ListTile's onTap
  Future<void> _selectDate(BuildContext context) async {
     final DateTime? picked = await showDatePicker(
         context: context,
         initialDate: _selectedDate ?? DateTime.now(),
         firstDate: DateTime.now().subtract(Duration(days: 30)),
         lastDate: DateTime.now().add(Duration(days: 365 * 2)),
     );
     if (picked != null && picked != _selectedDate) {
         setState(() { _selectedDate = picked; });
     }
  }

  Future<void> _updateList() async {
    if (_selectedDate == null) { /* ... Date validation ... */ return; }
    if (!_formKey.currentState!.validate()) return;
    final user = _auth.currentUser;
    if (user == null) { /* ... Error handling ... */ return; }

    setState(() { _isSaving = true; });
    try {
      final int numberOfSpots = int.tryParse(_spotsController.text) ?? 0;
      final int numberOfWaitlistSpots = int.tryParse(_waitlistController.text) ?? 0;
      final int numberOfBucketSpots = int.tryParse(_bucketController.text) ?? 0;
      final String stateValue = _stateController.text.trim().toUpperCase();

      final Map<String, dynamic> updatedData = {
        'listName': _listNameController.text.trim(),
        'venueName': _venueNameController.text.trim(), // Keep if using this field name
        // 'address': _venueNameController.text.trim(), // Or use if field name is address
        'date': Timestamp.fromDate(_selectedDate!),
        'state': stateValue.isNotEmpty ? stateValue : FieldValue.delete(),
        'numberOfSpots': numberOfSpots,
        'numberOfWaitlistSpots': numberOfWaitlistSpots,
        'numberOfBucketSpots': numberOfBucketSpots,
      };
      await _firestore.collection('Lists').doc(widget.listId).update(updatedData);
      if (mounted) { /* ... Success handling ... */ Navigator.pop(context); }
    } catch (e) { /* ... Error handling ... */ }
    finally { if (mounted) setState(() { _isSaving = false; }); }
  }

  // --- CORRECTED _buildNumberTextField ---
  Widget _buildNumberTextField({ required TextEditingController controller, required String label }) {
     // Added return statement
     return TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, filled: true, fillColor: Colors.white.withOpacity(0.8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), counterText: ""),
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
        maxLength: 3,
        validator: (value) { if (value == null || value.isEmpty) return null; final number = int.tryParse(value); if (number == null) return 'Invalid number'; if (number < 0) return 'Cannot be negative'; return null; }
     );
  }
  // --- END CORRECTION ---

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color buttonColor = Colors.blue.shade600;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor, elevation: 0, foregroundColor: Colors.white,
        title: Text('Edit List'),
      ),
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Colors.blue.shade200, Colors.purple.shade100])),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: appBarColor))
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    FadeInDown(duration: const Duration(milliseconds: 500), child: TextFormField(controller: _listNameController, decoration: InputDecoration(labelText: 'List Name', filled: true, fillColor: Colors.white.withOpacity(0.8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), validator: (v)=>(v==null||v.trim().isEmpty)?'Enter name':null)),
                    const SizedBox(height: 16),
                    // Address/Venue Field (Using _venueNameController - RENAME if needed)
                    FadeInDown(duration: const Duration(milliseconds: 600), child: TextFormField(controller: _venueNameController, decoration: InputDecoration(labelText: 'Venue/Address', filled: true, fillColor: Colors.white.withOpacity(0.8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), validator: (v)=>(v==null||v.trim().isEmpty)?'Enter venue/address':null)),
                    const SizedBox(height: 16),
                    // Date Picker Tile - Ensure onTap calls _selectDate
                    FadeInDown(
                       duration: const Duration(milliseconds: 700),
                       child: Card(
                          color: Colors.white.withOpacity(0.8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0,
                          child: ListTile(
                             leading: Icon(Icons.calendar_today, color: Colors.grey.shade700),
                             title: Text('Show Date', style: TextStyle(color: Colors.grey.shade700)),
                             subtitle: Text(_selectedDate == null ? 'Select Date' : DateFormat('EEE, MMM d, yyyy').format(_selectedDate!), style: TextStyle(color: _selectedDate == null ? Colors.grey.shade500 : Colors.black87, fontWeight: FontWeight.w500)),
                             // --- Ensure onTap calls _selectDate ---
                             onTap: () => _selectDate(context),
                             // --- End Ensure ---
                             trailing: Icon(Icons.arrow_drop_down)
                          )
                       )
                    ),
                    const SizedBox(height: 16),
                    // State Field
                    FadeInDown(duration: const Duration(milliseconds: 800), child: TextFormField(controller: _stateController, decoration: InputDecoration(labelText: 'State Abbreviation', hintText: 'e.g., CA (for search)', filled: true, fillColor: Colors.white.withOpacity(0.8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), maxLength: 2, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]'))], textCapitalization: TextCapitalization.characters, validator: (value) { if (value != null && value.isNotEmpty && value.length != 2) return 'Must be 2 letters'; return null; } )),
                    const SizedBox(height: 24),
                    // Spot Number Fields
                    FadeInDown(duration: const Duration(milliseconds: 900), child: _buildNumberTextField(controller: _spotsController, label: 'Number of Regular Spots')),
                    const SizedBox(height: 16),
                    FadeInDown(duration: const Duration(milliseconds: 1000), child: _buildNumberTextField(controller: _waitlistController, label: 'Number of Waitlist Spots')),
                    const SizedBox(height: 16),
                    FadeInDown(duration: const Duration(milliseconds: 1100), child: _buildNumberTextField(controller: _bucketController, label: 'Number of Bucket Spots')),
                    const SizedBox(height: 32),
                    // Save Button
                    _isSaving ? Center(child: CircularProgressIndicator(color: buttonColor)) : ElasticIn(duration: const Duration(milliseconds: 800), delay: const Duration(milliseconds: 200), child: ElevatedButton(onPressed: _updateList, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: buttonColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))), child: const Text('Save Changes', style: TextStyle(fontSize: 18, color: Colors.white)))),
                  ],
                ),
              ),
      ),
    );
  }
}