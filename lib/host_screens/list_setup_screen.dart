// lib/host_screens/list_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Keep for FilteringTextInputFormatter
import 'package:cloud_firestore/cloud_firestore.dart'; // Keep for Timestamp
import 'package:firebase_auth/firebase_auth.dart'; // Keep for FirebaseAuth
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart'; // Keep for DateFormat
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/firestore_provider.dart';
import 'package:myapp/models/show.dart';

import 'created_lists_screen.dart'; // Keep for navigation

class ListSetupScreen extends StatefulWidget {
  // Use super parameter
  const ListSetupScreen({super.key});
  @override
  State<ListSetupScreen> createState() => _ListSetupScreenState();
}

class _ListSetupScreenState extends State<ListSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _listNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _spotsController = TextEditingController(text: '15');
  final _waitlistController = TextEditingController(text: '0');
  final _bucketController = TextEditingController(text: '0');
  // Removed _stateController

  String? _selectedAddressDescription;
  String? _selectedStateAbbr;
  double? _selectedLat;
  double? _selectedLng;

  DateTime? _selectedDate;
  bool _isLoading = false;

  final String googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'MISSING_API_KEY';

  @override
  @mustCallSuper
  void dispose() {
    _listNameController.dispose();
    _addressController.dispose();
    _spotsController.dispose();
    _waitlistController.dispose();
    _bucketController.dispose();
    super.dispose();
  }

  // Keep _selectDate - used by DatePicker ListTile
  Future<void> _selectDate(BuildContext context) async {
     final DateTime? picked = await showDatePicker(
         context: context, initialDate: _selectedDate ?? DateTime.now(),
         firstDate: DateTime.now().subtract(Duration(days: 1)), lastDate: DateTime.now().add(Duration(days: 365 * 2)),
     );
     if (picked != null && picked != _selectedDate) setState(() => _selectedDate = picked);
  }

  // Keep _extractStateAbbr - used by Autocomplete callback
  String? _extractStateAbbr(Prediction prediction) {
     if (prediction.terms != null && prediction.terms!.length >= 2) { final stateTerm = prediction.terms![prediction.terms!.length - 2]; if (stateTerm.value != null && stateTerm.value!.length == 2 && RegExp(r'^[a-zA-Z]+$').hasMatch(stateTerm.value!)) return stateTerm.value!.toUpperCase(); }
     if (prediction.structuredFormatting?.secondaryText != null) { final parts = prediction.structuredFormatting!.secondaryText!.split(', '); if (parts.length >= 2) { final statePart = parts[parts.length - 2]; if (statePart.length == 2 && RegExp(r'^[a-zA-Z]+$').hasMatch(statePart)) return statePart.toUpperCase(); } }
     // print("Warning: Could not reliably extract state..."); // Commented out
     return null; // Added return
  }

  Future<void> _createList() async {
    if (_selectedAddressDescription == null || _selectedAddressDescription!.isEmpty) { /* ... Address validation ... */ return; }
    if (_selectedStateAbbr == null) { /* ... State validation ... */ return; }
    if (_selectedDate == null) { /* ... Date validation ... */ return; }
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { /* ... User validation ... */ return; }

    setState(() { _isLoading = true; });
    try {
      final int numberOfSpots = int.tryParse(_spotsController.text) ?? 0;
      final int numberOfWaitlistSpots = int.tryParse(_waitlistController.text) ?? 0;
      final int numberOfBucketSpots = int.tryParse(_bucketController.text) ?? 0;

      final newShow = Show(
         id: '', showName: _listNameController.text.trim(),
         address: _selectedAddressDescription!, state: _selectedStateAbbr!,
         latitude: _selectedLat, longitude: _selectedLng, date: _selectedDate!,
         numberOfSpots: numberOfSpots, numberOfWaitlistSpots: numberOfWaitlistSpots,
         numberOfBucketSpots: numberOfBucketSpots, userId: user.uid,
         bucketSpots: numberOfBucketSpots > 0, spots: {}, signedUpUserIds: [],
      );

      await context.read<FirestoreProvider>().createShow(newShow);

      if (mounted) { /* ... success handling ... */ }
    } catch (e) { /* ... error handling ... */ }
    finally { if (mounted) setState(() { _isLoading = false; }); }
  }

  Widget _buildNumberTextField({ required TextEditingController controller, required String label }) {
     return TextFormField( /* ... TextFormField definition ... */ );
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color buttonColor = Colors.blue.shade600;
    // Removed unused labelColor

    // --- Initialize bodyContent ---
    Widget bodyContent;
    if (googleApiKey == 'MISSING_API_KEY') {
       bodyContent = Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text('ERROR: GOOGLE_MAPS_API_KEY is missing...', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center)));
    } else {
       bodyContent = Form(
          key: _formKey,
          child: ListView(
             padding: const EdgeInsets.all(16.0),
             children: [
                FadeInDown(duration: const Duration(milliseconds: 500), child: TextFormField(controller: _listNameController, /* ... */)),
                const SizedBox(height: 16),
                FadeInDown(
                   duration: const Duration(milliseconds: 600),
                   child: GooglePlaceAutoCompleteTextField(
                      textEditingController: _addressController,
                      googleAPIKey: googleApiKey,
                      inputDecoration: InputDecoration(labelText: "Address / Venue", /* ... */),
                      getPlaceDetailWithLatLng: (Prediction prediction) { /* ... Update state ... */ },
                      itemClick: (Prediction prediction) { /* ... Update controller ... */ },
                   ),
                ),
                const SizedBox(height: 16),
                FadeInDown(duration: const Duration(milliseconds: 700), child: Card(color: Colors.white.withAlpha((255 * 0.9).round()), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0, child: ListTile(leading: Icon(Icons.calendar_today, color: Colors.grey.shade700), title: Text('Show Date', style: TextStyle(color: Colors.grey.shade700)), subtitle: Text(_selectedDate == null ? 'Select Date' : DateFormat('EEE, MMM d, yyyy').format(_selectedDate!), style: TextStyle(color: _selectedDate == null ? Colors.grey.shade500 : Colors.black87, fontWeight: FontWeight.w500)), onTap: () => _selectDate(context), trailing: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700)))),
                const SizedBox(height: 24),
                // Removed State TextFormField
                FadeInDown(duration: const Duration(milliseconds: 800), child: _buildNumberTextField(controller: _spotsController, label: 'Number of Regular Spots')),
                const SizedBox(height: 16),
                FadeInDown(duration: const Duration(milliseconds: 900), child: _buildNumberTextField(controller: _waitlistController, label: 'Number of Waitlist Spots')),
                const SizedBox(height: 16),
                FadeInDown(duration: const Duration(milliseconds: 1000), child: _buildNumberTextField(controller: _bucketController, label: 'Number of Bucket Spots')),
                const SizedBox(height: 32),
                _isLoading ? Center(child: CircularProgressIndicator(color: buttonColor)) : ElasticIn(duration: const Duration(milliseconds: 800), delay: const Duration(milliseconds: 200), child: ElevatedButton(onPressed: _createList, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: buttonColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))), child: const Text('Create List', style: TextStyle(fontSize: 18, color: Colors.white)))),
             ],
          ),
       );
    }
    // --- End Initialize ---

    return Scaffold(
      appBar: AppBar( /* ... AppBar setup ... */ ),
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Colors.blue.shade200, Colors.purple.shade100])),
        child: bodyContent, // Use variable
      ),
    );
  }
}