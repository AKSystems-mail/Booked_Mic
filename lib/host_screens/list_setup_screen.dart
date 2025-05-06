// lib/host_screens/list_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/firestore_provider.dart';
import 'package:myapp/models/show.dart'; // Assuming your Show model is here
// import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp

import 'created_lists_screen.dart';

class ListSetupScreen extends StatefulWidget {
  const ListSetupScreen({super.key});
  @override
  State<ListSetupScreen> createState() => _ListSetupScreenState();
}

class _ListSetupScreenState extends State<ListSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _listNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _spotsController = TextEditingController(text: '10');
  final _waitlistController = TextEditingController(text: '0');
  final _bucketController = TextEditingController(text: '0');
  late FocusNode _addressFocusNode; // <<< 1. Declare FocusNode

  // State for Address Autocomplete
  String? _selectedAddressDescription;
  String? _selectedStateAbbr;
  double? _selectedLat;
  double? _selectedLng;

  DateTime? _selectedDate;
  bool _isLoading = false;

  final String googleApiKey =
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'MISSING_API_KEY';

  @override
  void initState() {
    super.initState();
    _addressFocusNode = FocusNode(); // <<< 2. Initialize FocusNode
  }

  @override
  @mustCallSuper
  void dispose() {
    _listNameController.dispose();
    _addressController.dispose();
    _spotsController.dispose();
    _waitlistController.dispose();
    _bucketController.dispose();
    _addressFocusNode.dispose(); // <<< 3. Dispose FocusNode
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(Duration(days: 1)), // Ensure firstDate is not after initialDate
      lastDate: DateTime.now().add(Duration(days: 365 * 2)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String? _extractStateAbbr(Prediction prediction) {
     // Try to get state from 'terms' array first
    if (prediction.terms != null && prediction.terms!.length >= 2) {
      // State is often the second to last term for US addresses
      // e.g., [..., "City", "ST", "Country"] or [..., "City", "ST", "ZIP Code"]
      // Iterate backwards from second to last term to find a 2-letter state code
      for (int i = prediction.terms!.length - 2; i >= 0; i--) {
        final termValue = prediction.terms![i].value;
        if (termValue != null && termValue.length == 2 && RegExp(r'^[a-zA-Z]+$').hasMatch(termValue)) {
          return termValue.toUpperCase();
        }
      }
    }
    // Fallback: Check structured_formatting secondary_text (e.g., "City, ST, USA" or "City, ST ZIP")
    if (prediction.structuredFormatting?.secondaryText != null) {
      final parts = prediction.structuredFormatting!.secondaryText!.split(', ');
      if (parts.length >= 2) { // Need at least "City, ST"
        String potentialState = parts[1].trim(); // State is usually the second part
         // Handle cases like "ST ZIP" by removing ZIP
        if (potentialState.contains(" ")) {
            potentialState = potentialState.split(" ")[0];
        }
        if (potentialState.length == 2 && RegExp(r'^[a-zA-Z]+$').hasMatch(potentialState)) {
          return potentialState.toUpperCase();
        }
      }
    }
    return null;
  }

  // This method will only update internal state variables, NO setState HERE
  void _updateAddressDetails(Prediction prediction) {
    _selectedAddressDescription = prediction.description;
    _selectedLat = double.tryParse(prediction.lat ?? '');
    _selectedLng = double.tryParse(prediction.lng ?? '');
    _selectedStateAbbr = _extractStateAbbr(prediction);

    if (_selectedStateAbbr == null && mounted) {
      // Use WidgetsBinding to schedule the SnackBar after the current frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Re-check mounted as the callback is now async
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Could not automatically determine state from address (details will be saved).'),
              backgroundColor: Colors.orange));
        }
      });
    }
  }

  Future<void> _createList() async {
     if (_selectedAddressDescription == null ||
        _selectedAddressDescription!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Please select a valid address using the search.')));
      return;
    }
    if (_selectedStateAbbr == null || _selectedStateAbbr!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Could not determine state from selected address. Please try a different address format or ensure the selection is complete.'),
          backgroundColor: Colors.orange));
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Please select a date.')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: You must be logged in.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final int numberOfSpots = int.tryParse(_spotsController.text) ?? 0;
      final int numberOfWaitlistSpots =
          int.tryParse(_waitlistController.text) ?? 0;
      final int numberOfBucketSpots = int.tryParse(_bucketController.text) ?? 0;

      final newShow = Show(
        id: '', // Firestore will generate this
        showName: _listNameController.text.trim(),
        address: _selectedAddressDescription!,
        state: _selectedStateAbbr!,
        latitude: _selectedLat,
        longitude: _selectedLng,
        date: _selectedDate!,
        numberOfSpots: numberOfSpots,
        numberOfWaitlistSpots: numberOfWaitlistSpots,
        numberOfBucketSpots: numberOfBucketSpots,
        bucketSpots: numberOfBucketSpots > 0,
        userId: user.uid,
        // Assuming 'bucketSpots' boolean is not part of Show model based on edit screen
        spots: {},
        signedUpUserIds: [],
        // createdAt will be handled by FirestoreProvider or Firestore itself if configured
      );

      await context.read<FirestoreProvider>().createShow(newShow);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('List created successfully!')));
        // Navigate to CreatedListsScreen after successful creation
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => CreatedListsScreen()),
          (Route<dynamic> route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error creating list: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildNumberTextField(
      {required TextEditingController controller, required String label}) {
    return TextFormField(
        controller: controller,
        style: TextStyle(color: Colors.black87),
        decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey.shade700),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade400)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: Theme.of(context).primaryColor, width: 2.0)),
            counterText: ""),
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly
        ],
        maxLength: 3,
        validator: (value) {
          if (value == null || value.isEmpty) return null; // Allow 0 spots
          final number = int.tryParse(value);
          if (number == null) return 'Invalid number';
          if (number < 0) return 'Cannot be negative';
          return null;
        });
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color buttonColor = Colors.blue.shade600;
    final Color labelColor = Colors.grey.shade800;

    Widget bodyContent;
    if (googleApiKey == 'MISSING_API_KEY') {
      bodyContent = Center(
          child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                  'ERROR: GOOGLE_MAPS_API_KEY is missing in your .env file. Address search will not work.',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                  textAlign: TextAlign.center)));
    } else {
      bodyContent = Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            FadeInDown(
                duration: const Duration(milliseconds: 500),
                child: TextFormField(
                    controller: _listNameController,
                    style: TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                        labelText: 'List Name',
                        labelStyle: TextStyle(color: labelColor),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: Colors.grey.shade400)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 1.5))),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter name' : null)),
            const SizedBox(height: 16),
            FadeInDown(
              duration: const Duration(milliseconds: 600),
              child: GooglePlaceAutoCompleteTextField(
                textEditingController: _addressController,
                googleAPIKey: googleApiKey,
                focusNode: _addressFocusNode, // <<< 4. Assign FocusNode
                inputDecoration: InputDecoration(
                    labelText: "Address / Venue",
                    labelStyle: TextStyle(color: labelColor),
                    hintText: "Search Address or Venue",
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade400)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: Theme.of(context).primaryColor, width: 1.5)),
                    prefixIcon: Icon(Icons.location_on_outlined,
                        color: Colors.grey.shade700)),
                debounceTime: 400, // ms
                countries: ["us"],
                isLatLngRequired: true,
                getPlaceDetailWithLatLng: _updateAddressDetails, // Assign the new method
                itemClick: (Prediction prediction) {
                  _addressController.text = prediction.description ?? '';
                  _addressController.selection = TextSelection.fromPosition(
                      TextPosition(
                          offset: prediction.description?.length ?? 0));
                  _updateAddressDetails(prediction); // Update internal state variables

                  // Request focus after the current frame to ensure other UI updates have settled
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _addressFocusNode.canRequestFocus) { // Check if widget is still mounted and node can request focus
                      _addressFocusNode.requestFocus();
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            FadeInDown(
                duration: const Duration(milliseconds: 700),
                child: Card(
                    color: Colors.white.withAlpha((255 * 0.9).round()),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                    child: ListTile(
                        leading: Icon(Icons.calendar_today,
                            color: Colors.grey.shade700),
                        title: Text('Show Date',
                            style: TextStyle(color: Colors.grey.shade700)),
                        subtitle: Text(
                            _selectedDate == null
                                ? 'Select Date'
                                : DateFormat('EEE, MMM d, yyyy')
                                    .format(_selectedDate!),
                            style: TextStyle(
                                color: _selectedDate == null
                                    ? Colors.grey.shade500
                                    : Colors.black87,
                                fontWeight: FontWeight.w500)),
                        onTap: () => _selectDate(context),
                        trailing: Icon(Icons.arrow_drop_down,
                            color: Colors.grey.shade700)))),
            const SizedBox(height: 24),
            FadeInDown(
                duration: const Duration(milliseconds: 800),
                child: _buildNumberTextField(
                    controller: _spotsController,
                    label: 'Number of Regular Spots')),
            const SizedBox(height: 16),
            FadeInDown(
                duration: const Duration(milliseconds: 900),
                child: _buildNumberTextField(
                    controller: _waitlistController,
                    label: 'Number of Waitlist Spots')),
            const SizedBox(height: 16),
            FadeInDown(
                duration: const Duration(milliseconds: 1000),
                child: _buildNumberTextField(
                    controller: _bucketController,
                    label: 'Number of Bucket Spots')),
            const SizedBox(height: 32),
            _isLoading
                ? Center(child: CircularProgressIndicator(color: buttonColor))
                : ElasticIn(
                    duration: const Duration(milliseconds: 800),
                    delay: const Duration(milliseconds: 200),
                    child: ElevatedButton(
                        onPressed: _createList,
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: buttonColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0))),
                        child: const Text('Create List',
                            style:
                                TextStyle(fontSize: 18, color: Colors.white)))),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        title:
            const Text('Setup New List', style: TextStyle(color: Colors.white)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                // Fallback for web or if no previous route
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => CreatedListsScreen()));
              }
            }
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Colors.blue.shade200, Colors.purple.shade100])),
        child: bodyContent,
      ),
    );
  }
}
