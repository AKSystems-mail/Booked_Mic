// lib/host_screens/list_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Make sure this is imported for Timestamp
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart'; // Keep if used by FirestoreProvider or other providers
import 'package:myapp/providers/firestore_provider.dart'; // Assuming this is your path
import 'package:myapp/models/show.dart'; // Assuming your Show model is here

import 'created_lists_screen.dart'; // For navigation

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
  late FocusNode _addressFocusNode;

  String? _selectedAddressDescription;
  String? _selectedStateAbbr;
  double? _selectedLat;
  double? _selectedLng;

  DateTime? _selectedDate;
  bool _isLoading = false;
  String? _errorMessage; // For displaying errors to the user

  final String googleApiKey =
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'MISSING_API_KEY';

  @override
  void initState() {
    super.initState();
    _addressFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _listNameController.dispose();
    _addressController.dispose();
    _spotsController.dispose();
    _waitlistController.dispose();
    _bucketController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(Duration(days: 1)),
      lastDate: DateTime.now().add(Duration(days: 365 * 2)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String? _extractStateAbbr(Prediction prediction) {
    if (prediction.terms != null && prediction.terms!.length >= 2) {
      for (int i = prediction.terms!.length - 2; i >= 0; i--) {
        final termValue = prediction.terms![i].value;
        if (termValue != null && termValue.length == 2 && RegExp(r'^[a-zA-Z]+$').hasMatch(termValue)) {
          return termValue.toUpperCase();
        }
      }
    }
    if (prediction.structuredFormatting?.secondaryText != null) {
      final parts = prediction.structuredFormatting!.secondaryText!.split(', ');
      if (parts.length >= 2) {
        String potentialState = parts[1].trim();
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

  void _updateAddressDetails(Prediction prediction) {
    // These assignments update the state variables directly.
    // The UI will use these values when _createList is called.
    _selectedAddressDescription = prediction.description;
    _selectedLat = double.tryParse(prediction.lat ?? '');
    _selectedLng = double.tryParse(prediction.lng ?? '');
    _selectedStateAbbr = _extractStateAbbr(prediction);

    // Update the text controller as well so the user sees the selected address
    _addressController.text = prediction.description ?? '';
    _addressController.selection = TextSelection.fromPosition(
        TextPosition(offset: prediction.description?.length ?? 0));


    if (_selectedStateAbbr == null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Could not automatically determine state from address (details will be saved).'),
              backgroundColor: Colors.orange));
        }
      });
    }
  }

  Future<void> _createList() async {
    // Clear previous error messages
    setState(() { _errorMessage = null; });

    // Basic Validations first
    if (!_formKey.currentState!.validate()) return;

    if (_selectedAddressDescription == null || _selectedAddressDescription!.trim().isEmpty) {
      // This check is important because _addressController.text might have user typed input
      // but _selectedAddressDescription is only set when a suggestion is chosen.
      // We rely on a chosen suggestion for lat, lng, state.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please select a valid address using the search suggestions.')));
      }
      return;
    }
    // _selectedStateAbbr check is now part of the conflict check logic,
    // but we can keep a basic one here too.
    if (_selectedStateAbbr == null || _selectedStateAbbr!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not determine state. Please select a more specific address.'),
            backgroundColor: Colors.orange));
      }
      return;
    }
    if (_selectedDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a date.')));
      }
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: You must be logged in.')));
      }
      return;
    }

    setState(() => _isLoading = true);

    // --- Normalize Data for Conflict Check ---
    final DateTime dateOnly = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
    final Timestamp dateTimestampForCheck = Timestamp.fromDate(dateOnly);
    final String normalizedAddressForCheck = _selectedAddressDescription!.trim().toLowerCase(); // Use selected description

    try {
      // --- Perform Conflict Check ---

      final querySnapshot = await FirebaseFirestore.instance
          .collection('Lists')
          .where('date', isEqualTo: dateTimestampForCheck)
          // Consider adding .where('normalizedAddress', isEqualTo: normalizedAddressForCheck)
          // if you implement storing normalizedAddress in Firestore.
          .get();

      bool conflictFound = false;
      if (querySnapshot.docs.isNotEmpty) {
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          String storedAddress = (data['address'] as String? ?? "").trim().toLowerCase();
          // More robust: compare normalizedAddress if you store it, or lat/lng if available
          // String storedNormalizedAddress = (data['normalizedAddress'] as String? ?? "").trim().toLowerCase();
          // if (storedNormalizedAddress == normalizedAddressForCheck) { ... }

          if (storedAddress == normalizedAddressForCheck) { // Basic check
            if (data['userId'] != user.uid) {
              conflictFound = true;
              break;
            }
          }
        }
      }

      if (conflictFound) {
        if (mounted) {
          setState(() {
            _errorMessage = 'A list by another host already exists for this date and address.';
            _isLoading = false;
          });
        }
        return;
      }

      // --- No Conflict Found - Proceed to Create List ---
      final int numberOfSpots = int.tryParse(_spotsController.text.trim()) ?? 0;
      final int numberOfWaitlistSpots = int.tryParse(_waitlistController.text.trim()) ?? 0;
      final int numberOfBucketSpots = int.tryParse(_bucketController.text.trim()) ?? 0;

      // Using your Show model and FirestoreProvider
      final newShow = Show(
        id: '', // FirestoreProvider or Firestore will generate this
        showName: _listNameController.text.trim(),
        address: _selectedAddressDescription!,
        normalizedAddress: _selectedAddressDescription!.trim().toLowerCase(), // <<< ADDED THIS LINE // Use the confirmed selected address
        state: _selectedStateAbbr!,
        latitude: _selectedLat,
        longitude: _selectedLng,
        date: _selectedDate!, // This is DateTime, FirestoreProvider should handle conversion to Timestamp
        numberOfSpots: numberOfSpots,
        numberOfWaitlistSpots: numberOfWaitlistSpots,
        numberOfBucketSpots: numberOfBucketSpots,
        bucketSpots: numberOfBucketSpots > 0, // Assuming this logic is correct for your model
        userId: user.uid,
        spots: {},
        signedUpUserIds: [],
        // createdAt will be handled by FirestoreProvider or Firestore (e.g. FieldValue.serverTimestamp())
      );

      // Assuming your FirestoreProvider's createShow handles setting the ID and Timestamps
      await context.read<FirestoreProvider>().createShow(newShow);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('List created successfully!'), backgroundColor: Colors.green));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => CreatedListsScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to create list: ${e.toString()}';
        });
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
    // ... (your existing _buildNumberTextField method - looks good)
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
          if (value == null || value.isEmpty) return null;
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
      // ... (your existing MISSING_API_KEY widget)
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
            // ... (List Name TextFormField)
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
            // ... (GooglePlaceAutoCompleteTextField)
            FadeInDown(
              duration: const Duration(milliseconds: 600),
              child: GooglePlaceAutoCompleteTextField(
                textEditingController: _addressController,
                googleAPIKey: googleApiKey,
                focusNode: _addressFocusNode,
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
                debounceTime: 400,
                countries: ["us"],
                isLatLngRequired: true,
                getPlaceDetailWithLatLng: _updateAddressDetails, // Correct: No setState here
                itemClick: (Prediction prediction) {
                  // This updates the controller and internal state vars
                  _updateAddressDetails(prediction);

                  // Optional: Refocus after selection if desired, though often not needed
                  // WidgetsBinding.instance.addPostFrameCallback((_) {
                  //   if (mounted && _addressFocusNode.canRequestFocus) {
                  //     _addressFocusNode.requestFocus();
                  //   }
                  // });
                },
              ),
            ),
            const SizedBox(height: 16),
            // ... (Date Picker ListTile)
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
            // ... (Number TextFields)
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
            const SizedBox(height: 24), // Space before error message

            // --- ERROR MESSAGE DISPLAY ---
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: FadeIn( // Optional: Animate error message
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            SizedBox(height: _errorMessage != null ? 12 : 0), // Space after error message

            // ... (Loading Indicator or Create Button)
            _isLoading
                ? Center(child: CircularProgressIndicator(color: buttonColor))
                : ElasticIn(
                    duration: const Duration(milliseconds: 800),
                    delay: const Duration(milliseconds: 200),
                    child: ElevatedButton(
                        onPressed: _createList, // This now includes the conflict check
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: buttonColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0))),
                        child: const Text('Create List',
                            style:
                                TextStyle(fontSize: 18, color: Colors.white)))),
            SizedBox(height: 20), // Bottom padding
          ],
        ),
      );
    }

    return Scaffold(
      // ... (Your existing Scaffold AppBar and main body Container)
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