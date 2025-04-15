// lib/host_screens/edit_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Removed unused import: import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Keep for DateFormat
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:myapp/providers/firestore_provider.dart';
// Keep Show model import

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
  void initState() {
    super.initState();
    _listNameController = TextEditingController();
    _spotsController = TextEditingController();
    _waitlistController = TextEditingController();
    _bucketController = TextEditingController();
    _addressController = TextEditingController();
    _fetchListData();
  }

  @override
  @mustCallSuper
  void dispose() {
    _listNameController.dispose();
    _spotsController.dispose();
    _waitlistController.dispose();
    _bucketController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchListData() async {
    setState(() { _isLoading = true; });
    try {
      final firestoreProvider = context.read<FirestoreProvider>();
      final showData = await firestoreProvider.getShow(widget.listId).first;

      if (mounted) {
        _listNameController.text = showData.showName;
        _spotsController.text = showData.numberOfSpots.toString();
        _waitlistController.text = showData.numberOfWaitlistSpots.toString();
        _bucketController.text = showData.numberOfBucketSpots.toString();
        _selectedAddressDescription = showData.address;
        _addressController.text = _selectedAddressDescription ?? '';
        _selectedStateAbbr = showData.state;
        _selectedLat = showData.latitude;
        _selectedLng = showData.longitude;
        _selectedDate = showData.date;
        setState(() { _isLoading = false; });
      }
    } catch (e) {
      // print("Error fetching list data: $e"); // Commented out
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching list details: $e'), backgroundColor: Colors.red));
         Navigator.pop(context);
      }
    }
  }

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
     if (prediction.terms != null && prediction.terms!.length >= 2) { final stateTerm = prediction.terms![prediction.terms!.length - 2]; if (stateTerm.value != null && stateTerm.value!.length == 2 && RegExp(r'^[a-zA-Z]+$').hasMatch(stateTerm.value!)) return stateTerm.value!.toUpperCase(); }
     if (prediction.structuredFormatting?.secondaryText != null) { final parts = prediction.structuredFormatting!.secondaryText!.split(', '); if (parts.length >= 2) { final statePart = parts[parts.length - 2]; if (statePart.length == 2 && RegExp(r'^[a-zA-Z]+$').hasMatch(statePart)) return statePart.toUpperCase(); } }
     // print("Warning: Could not reliably extract state..."); // Commented out
     return null; // Added return
  }

  Future<void> _updateList() async {
    if (_selectedAddressDescription == null || _selectedAddressDescription!.isEmpty || _selectedStateAbbr == null || _selectedStateAbbr!.isEmpty) { /* ... Address validation ... */ return; }
    if (_selectedDate == null) { /* ... Date validation ... */ return; }
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isSaving = true; });
    try {
      final int numberOfSpots = int.tryParse(_spotsController.text) ?? 0;
      final int numberOfWaitlistSpots = int.tryParse(_waitlistController.text) ?? 0;
      final int numberOfBucketSpots = int.tryParse(_bucketController.text) ?? 0;

      // Create the update map directly
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

      // Use provider to update using the Map
      await context.read<FirestoreProvider>().updateShowMap(widget.listId, updatedData);

      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('List updated successfully!'))); Navigator.pop(context); }
    } catch (e) {
       // print("Error updating list: $e"); // Commented out
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating list: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  Widget _buildNumberTextField({ required TextEditingController controller, required String label }) {
     return TextFormField(controller: controller, style: TextStyle(color: Colors.black87), decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: Colors.grey.shade700), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade400)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0)), counterText: ""), keyboardType: TextInputType.number, inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly], maxLength: 3, validator: (value) { if (value == null || value.isEmpty) return null; final number = int.tryParse(value); if (number == null) return 'Invalid number'; if (number < 0) return 'Cannot be negative'; return null; });
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color buttonColor = Colors.blue.shade600;
    final Color labelColor = Colors.grey.shade800; // Used

    // Initialize bodyContent
    Widget bodyContent;
    if (googleApiKey == 'MISSING_API_KEY') {
       bodyContent = Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text('ERROR: GOOGLE_MAPS_API_KEY is missing...', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center)));
    } else {
       bodyContent = Form(
          key: _formKey,
          child: ListView(
             padding: const EdgeInsets.all(16.0),
             children: [
                // Use FadeInDown if desired, otherwise remove
                TextFormField(controller: _listNameController, style: TextStyle(color: Colors.black87), decoration: InputDecoration(labelText: 'List Name', labelStyle: TextStyle(color: labelColor), /* ... borders ... */), validator: (v)=>(v==null||v.trim().isEmpty)?'Enter name':null),
                const SizedBox(height: 16),
                GooglePlaceAutoCompleteTextField(
                   textEditingController: _addressController,
                   googleAPIKey: googleApiKey,
                   inputDecoration: InputDecoration(labelText: "Address / Venue", labelStyle: TextStyle(color: labelColor), hintText: "Search Address or Venue", /* ... */),
                   getPlaceDetailWithLatLng: (Prediction prediction) {
                      _addressController.text = prediction.description ?? '';
                      setState(() {
                         _selectedAddressDescription = prediction.description;
                         _selectedLat = double.tryParse(prediction.lat ?? '');
                         _selectedLng = double.tryParse(prediction.lng ?? '');
                         // --- *** CALL _extractStateAbbr HERE *** ---
                         _selectedStateAbbr = _extractStateAbbr(prediction);
                      });
                      if (_selectedStateAbbr == null && mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not automatically determine state from address.'), backgroundColor: Colors.orange)); }
                   },
                   itemClick: (Prediction prediction) { /* ... */ },
                ),
                const SizedBox(height: 16),
                // Keep Date Picker - uses _selectDate and intl
                Card(color: Colors.white.withAlpha((255 * 0.9).round()), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0, child: ListTile(leading: Icon(Icons.calendar_today, color: Colors.grey.shade700), title: Text('Show Date', style: TextStyle(color: Colors.grey.shade700)), subtitle: Text(_selectedDate == null ? 'Select Date' : DateFormat('EEE, MMM d, yyyy').format(_selectedDate!), style: TextStyle(color: _selectedDate == null ? Colors.grey.shade500 : Colors.black87, fontWeight: FontWeight.w500)), onTap: () => _selectDate(context), trailing: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700))),
                const SizedBox(height: 24),
                _buildNumberTextField(controller: _spotsController, label: 'Number of Regular Spots'),
                const SizedBox(height: 16),
                _buildNumberTextField(controller: _waitlistController, label: 'Number of Waitlist Spots'),
                const SizedBox(height: 16),
                _buildNumberTextField(controller: _bucketController, label: 'Number of Bucket Spots'),
                const SizedBox(height: 32),
                _isSaving ? Center(child: CircularProgressIndicator(color: buttonColor)) : ElevatedButton(onPressed: _updateList, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: buttonColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))), child: const Text('Save Changes', style: TextStyle(fontSize: 18, color: Colors.white))),
             ],
          ),
       );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor, elevation: 0, foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text('Edit List', style: TextStyle(color: Colors.white)),
      ),
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Colors.blue.shade200, Colors.purple.shade100])),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: appBarColor))
            : bodyContent,
      ),
    );
  }
}