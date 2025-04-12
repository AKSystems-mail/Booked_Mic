// lib/host_screens/edit_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart'; // Keep for DateFormat
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EditListScreen extends StatefulWidget {
  final String listId;
  const EditListScreen({super.key, required this.listId});

  @override
  _EditListScreenState createState() => _EditListScreenState();
}

class _EditListScreenState extends State<EditListScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TextEditingController _listNameController;
  late TextEditingController _spotsController;
  late TextEditingController _waitlistController;
  late TextEditingController _bucketController;
  late TextEditingController _addressController; // Keep

  String? _selectedAddressDescription;
  String? _selectedStateAbbr;
  double? _selectedLat;
  double? _selectedLng;

  DateTime? _selectedDate;
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _initialData;

  final String googleApiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? 'MISSING_API_KEY';

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
      final docSnap = await _firestore.collection('Lists').doc(widget.listId).get();
      if (docSnap.exists && mounted) {
        _initialData = docSnap.data();
        _listNameController.text = _initialData?['listName'] ?? '';
        _spotsController.text = (_initialData?['numberOfSpots'] ?? 0).toString();
        _waitlistController.text = (_initialData?['numberOfWaitlistSpots'] ?? 0).toString();
        _bucketController.text = (_initialData?['numberOfBucketSpots'] ?? 0).toString();
        _selectedAddressDescription = _initialData?['address'];
        _addressController.text = _selectedAddressDescription ?? ''; // Set controller text
        _selectedStateAbbr = _initialData?['state'];
        _selectedLat = _initialData?['latitude'];
        _selectedLng = _initialData?['longitude'];
        final Timestamp? dateTimestamp = _initialData?['date'] as Timestamp?;
        _selectedDate = dateTimestamp?.toDate();
      } else {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: List not found.'), backgroundColor: Colors.red));
            Navigator.pop(context);
         }
      }
    } catch (e) {
      print("Error fetching list data: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching list details: $e'), backgroundColor: Colors.red));
         Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

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

  String? _extractStateAbbr(Prediction prediction) {
     if (prediction.terms != null && prediction.terms!.length >= 2) { final stateTerm = prediction.terms![prediction.terms!.length - 2]; if (stateTerm.value != null && stateTerm.value!.length == 2 && RegExp(r'^[a-zA-Z]+$').hasMatch(stateTerm.value!)) return stateTerm.value!.toUpperCase(); }
     if (prediction.structuredFormatting?.secondaryText != null) { final parts = prediction.structuredFormatting!.secondaryText!.split(', '); if (parts.length >= 2) { final statePart = parts[parts.length - 2]; if (statePart.length == 2 && RegExp(r'^[a-zA-Z]+$').hasMatch(statePart)) return statePart.toUpperCase(); } }
     print("Warning: Could not reliably extract state from prediction: ${prediction.description}");
     return null;
  }

  Future<void> _updateList() async {
    if (_selectedAddressDescription == null || _selectedAddressDescription!.isEmpty || _selectedStateAbbr == null || _selectedStateAbbr!.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a valid address using the search.'))); return; }
    if (_selectedDate == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a date.'))); return; }
    if (!_formKey.currentState!.validate()) return;
    final user = _auth.currentUser;
    if (user == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Not logged in.'), backgroundColor: Colors.red)); return; }

    setState(() { _isSaving = true; });
    try {
      final int numberOfSpots = int.tryParse(_spotsController.text) ?? 0;
      final int numberOfWaitlistSpots = int.tryParse(_waitlistController.text) ?? 0;
      final int numberOfBucketSpots = int.tryParse(_bucketController.text) ?? 0;

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
      await _firestore.collection('Lists').doc(widget.listId).update(updatedData);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('List updated successfully!'))); Navigator.pop(context); }
    } catch (e) {
       print("Error updating list: $e");
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating list: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  Widget _buildNumberTextField({ required TextEditingController controller, required String label }) {
     return TextFormField(controller: controller, style: TextStyle(color: Colors.black87), decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: Colors.grey.shade700), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade400)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0)), counterText: ""), keyboardType: TextInputType.number, inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly], maxLength: 3, validator: (value) { if (value == null || value.isEmpty) return null; final number = int.tryParse(value); if (number == null) return 'Invalid number'; if (number < 0) return 'Cannot be negative'; return null; });
  }

  Future<void> _showResetConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Reset'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('This will remove all names from the list.'),
                Text('Are you sure you want to proceed?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the dialog
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              child: const Text('Confirm'),
              onPressed: () {
                _resetList(); // Call the function to reset the list
                Navigator.of(context).pop(); // Dismiss the dialog
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetList() async {
    try {
      setState(() { _isSaving = true; });
      final listRef = _firestore.collection('Lists').doc(widget.listId);
      await listRef.update({'spots': <String, dynamic>{}});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('List has been reset. All names removed.')),
        );
      }
    } catch (e) {
      print("Error resetting list: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resetting list: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color buttonColor = Colors.blue.shade600;
    final Color labelColor = Colors.grey.shade800;

    Widget bodyContent;
    if (googleApiKey == 'MISSING_API_KEY') {
      bodyContent = Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text('ERROR: GOOGLE_PLACES_API_KEY is missing...', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center)));
    } else {
      bodyContent = Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            FadeInDown(duration: const Duration(milliseconds: 500), child: TextFormField(controller: _listNameController, style: TextStyle(color: Colors.black87), decoration: InputDecoration(labelText: 'List Name', labelStyle: TextStyle(color: labelColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade400)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5))), validator: (v)=>(v==null||v.trim().isEmpty)?'Enter name':null)),
            const SizedBox(height: 16),
            FadeInDown(
              duration: const Duration(milliseconds: 600),
              child: GooglePlaceAutoCompleteTextField(
                textEditingController: _addressController,
                googleAPIKey: googleApiKey,
                inputDecoration: InputDecoration(labelText: "Address / Venue", labelStyle: TextStyle(color: labelColor), hintText: "Search Address or Venue", hintStyle: TextStyle(color: Colors.grey.shade500), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade400)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5)), prefixIcon: Icon(Icons.location_on_outlined, color: Colors.grey.shade700)),
                debounceTime: 400, countries: ["us"], isLatLngRequired: true,
                getPlaceDetailWithLatLng: (Prediction prediction) {
                  _addressController.text = prediction.description ?? '';
                  setState(() { _selectedAddressDescription = prediction.description; _selectedLat = double.tryParse(prediction.lat ?? ''); _selectedLng = double.tryParse(prediction.lng ?? ''); _selectedStateAbbr = _extractStateAbbr(prediction); });
                  if (_selectedStateAbbr == null && mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not automatically determine state.'), backgroundColor: Colors.orange)); }
                },
                itemClick: (Prediction prediction) { _addressController.text = prediction.description ?? ''; _addressController.selection = TextSelection.fromPosition(TextPosition(offset: prediction.description?.length ?? 0)); },
              ),
            ),
            const SizedBox(height: 16),
            FadeInDown(duration: const Duration(milliseconds: 700), child: Card(color: Colors.white.withOpacity(0.9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0, child: ListTile(leading: Icon(Icons.calendar_today, color: Colors.grey.shade700), title: Text('Show Date', style: TextStyle(color: Colors.grey.shade700)), subtitle: Text(_selectedDate == null ? 'Select Date' : DateFormat('EEE, MMM d,<ctrl3348>').format(_selectedDate!), style: TextStyle(color: _selectedDate == null ? Colors.grey.shade500 : Colors.black87, fontWeight: FontWeight.w500)), onTap: () => _selectDate(context), trailing: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700)))),
            const SizedBox(height: 24),
            FadeInDown(duration: const Duration(milliseconds: 900), child: _buildNumberTextField(controller: _spotsController, label: 'Number of Regular Spots')),
            const SizedBox(height: 16),
            FadeInDown(duration: const Duration(milliseconds: 1000), child: _buildNumberTextField(controller: _waitlistController, label: 'Number of Waitlist Spots')),
            const SizedBox(height: 16),
            FadeInDown(duration: const Duration(milliseconds: 1100), child: _buildNumberTextField(controller: _bucketController, label: 'Number of Bucket Spots')),
            const SizedBox(height: 32),
            _isSaving ? Center(child: CircularProgressIndicator(color: buttonColor)) : ElasticIn(duration: const Duration(milliseconds: 800), delay: const Duration(milliseconds: 200), child: ElevatedButton(onPressed: _updateList, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: buttonColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))), child: const Text('Save Changes', style: TextStyle(fontSize: 18, color: Colors.white)))),
            const SizedBox(height: 16),
            FadeInDown(
              duration: const Duration(milliseconds: 1200),
              child: ElevatedButton(
                onPressed: _showResetConfirmationDialog,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: const Text('Reset List', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
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