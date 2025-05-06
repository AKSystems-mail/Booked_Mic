// lib/host_screens/edit_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';

import 'package:intl/intl.dart'; // Keep for DateFormat
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'package:myapp/providers/firestore_provider.dart';
import 'package:myapp/models/show.dart'; // Ensure your Show model is imported

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
  late FocusNode _addressFocusNode; // <<< 1. Declare FocusNode

  String? _selectedAddressDescription;
  String? _selectedStateAbbr;
  double? _selectedLat;
  double? _selectedLng;

  DateTime? _selectedDate;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isResetting = false;

  final String googleApiKey =
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'MISSING_API_KEY';

  @override
  void initState() {
    super.initState();
    _listNameController = TextEditingController();
    _spotsController = TextEditingController();
    _waitlistController = TextEditingController();
    _bucketController = TextEditingController();
    _addressController = TextEditingController();
    _addressFocusNode = FocusNode(); // <<< 2. Initialize FocusNode
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
    _addressFocusNode.dispose(); // <<< 3. Dispose FocusNode
    super.dispose();
  }

  Future<void> _fetchListData() async {
    try {
      final firestoreProvider = context.read<FirestoreProvider>();
      final Show showData = await firestoreProvider.getShow(widget.listId).first;

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
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error fetching list details: $e'),
            backgroundColor: Colors.red));
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
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
      setState(() => _selectedDate = picked);
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

  // <<< Define _updateAddressDetails method >>>
  // This method will only update internal state variables, NO setState HERE
  void _updateAddressDetails(Prediction prediction) {
    _selectedAddressDescription = prediction.description;
    _selectedLat = double.tryParse(prediction.lat ?? "0.0");
    _selectedLng = double.tryParse(prediction.lng ?? "0.0");
    _selectedStateAbbr = _extractStateAbbr(prediction);

    if (_selectedStateAbbr == null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Could not automatically determine state from address (details will be saved).'),
              backgroundColor: Colors.orange));
        }
      });
    }
  }

  Future<void> _updateList() async {
    if (_selectedAddressDescription == null ||
        _selectedAddressDescription!.isEmpty ||
        _selectedStateAbbr == null ||
        _selectedStateAbbr!.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Please select a valid address with a state using the search.'),
            backgroundColor: Colors.orange));
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Please select a date for the list.'),
            backgroundColor: Colors.orange));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });
    try {
      final int numberOfSpots = int.tryParse(_spotsController.text) ?? 0;
      final int numberOfWaitlistSpots =
          int.tryParse(_waitlistController.text) ?? 0;
      final int numberOfBucketSpots = int.tryParse(_bucketController.text) ?? 0;

      final Map<String, dynamic> updatedData = {
        'showName': _listNameController.text.trim(),
        'address': _selectedAddressDescription!,
        'state': _selectedStateAbbr!,
        'latitude': _selectedLat,
        'longitude': _selectedLng,
        'date': Timestamp.fromDate(_selectedDate!),
        'numberOfSpots': numberOfSpots,
        'numberOfWaitlistSpots': numberOfWaitlistSpots,
        'numberOfBucketSpots': numberOfBucketSpots,
      };
      await context
          .read<FirestoreProvider>()
          .updateShowMap(widget.listId, updatedData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('List updated successfully!')));
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error updating list: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
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
          if (value == null || value.isEmpty) return null;
          final number = int.tryParse(value);
          if (number == null) return 'Invalid number';
          if (number < 0) return 'Cannot be negative';
          return null;
        });
  }

  Future<void> _showResetConfirmationDialog() async {
     if (!mounted) return;
    final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text('Reset List Spots?'),
            content: Text(
                'This will remove ALL performer names and signups from this list. Are you sure?'),
            actions: <Widget>[
              TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(false)),
              TextButton(
                  child: Text('Reset List',
                      style: TextStyle(color: Colors.orange.shade700)),
                  onPressed: () => Navigator.of(dialogContext).pop(true)),
            ],
          );
        });

    if (confirm == true && mounted) {
      await _resetListSpots();
    }
  }

  Future<void> _resetListSpots() async {
    if (!mounted) return;
    setState(() {
      _isResetting = true;
    });
    try {
      await context.read<FirestoreProvider>().resetListSpots(widget.listId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('List spots reset successfully.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error resetting list spots: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color buttonColor = Colors.blue.shade600;
    final Color resetButtonBackgroundColor = Colors.red;
    final Color resetButtonTextColor = Colors.white;
    final Color labelColor = Colors.grey.shade800;

    return Scaffold(
        appBar: AppBar(
          backgroundColor: appBarColor,
          elevation: 0,
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
          title: Text('Edit List', style: TextStyle(color: Colors.white)),
        ),
        body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Colors.blue.shade200, Colors.purple.shade100])),
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: appBarColor))
                : (googleApiKey == 'MISSING_API_KEY'
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                                'ERROR: GOOGLE_MAPS_API_KEY is missing...',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                                textAlign: TextAlign.center)))
                    : Form(
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
                                      labelStyle: TextStyle(color:labelColor),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade400)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5)),
                                    ),
                                    textCapitalization: TextCapitalization.sentences,
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Enter name'
                                            : null)),
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
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade400)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5)),
                                  prefixIcon: Icon(Icons.location_on_outlined, color: Colors.grey.shade700),
                                ),
                                debounceTime: 400,
                                countries: ["us"],
                                isLatLngRequired: true,
                                getPlaceDetailWithLatLng: _updateAddressDetails, // <<< Use the new method here
                                itemClick: (Prediction prediction) {
                                  _addressController.text = prediction.description ?? '';
                                  _addressController.selection = TextSelection.fromPosition(
                                      TextPosition(offset: prediction.description?.length ?? 0));
                                  _updateAddressDetails(prediction); // Update internal state

                                  // Request focus after the current frame
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                     if (mounted && _addressFocusNode.canRequestFocus) {
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
                                    color: Colors.white
                                        .withAlpha((255 * 0.9).round()),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    elevation: 0,
                                    child: ListTile(
                                        leading: Icon(Icons.calendar_today,
                                            color: Colors.grey.shade700),
                                        title: Text('Show Date',
                                            style: TextStyle(
                                                color: Colors.grey.shade700)),
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
                                        trailing:
                                            Icon(Icons.arrow_drop_down, color: Colors.grey.shade700)))),
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
                            ElevatedButton(
                              onPressed: (_isSaving || _isResetting)
                                  ? null
                                  : _updateList,
                              style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: buttonColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10.0))),
                              child:
                                  (_isSaving)
                                      ? SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Text('Save Changes',
                                          style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.white)),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              icon: Icon(Icons.refresh,
                                  color: (_isSaving || _isResetting)
                                      ? Colors.grey // Icon color when disabled
                                      : resetButtonTextColor), // Icon color when enabled
                              label: Text('Reset List Spots', // Changed label
                                  style: TextStyle(
                                      color: (_isSaving || _isResetting)
                                          ? Colors.grey // Text color when disabled
                                          : resetButtonTextColor, // Text color when enabled
                                      fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (_isSaving || _isResetting)
                                    ? Colors.grey.shade300 // Background when disabled
                                    : resetButtonBackgroundColor, // Background when enabled
                                foregroundColor: resetButtonTextColor, // Default icon/text color (overridden above)
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.0)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: (_isSaving || _isResetting)
                                  ? null
                                  : _showResetConfirmationDialog,
                            )
                          ],
                        ),
                      )))
        );
  }
}
