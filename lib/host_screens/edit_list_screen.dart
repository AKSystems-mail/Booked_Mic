// lib/host_screens/edit_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EditListScreen extends StatefulWidget {
  final String listId;
  const EditListScreen({super.key, required this.listId});

  @override
  State<EditListScreen> createState() => _EditListScreenState();
}

class _EditListScreenState extends State<EditListScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TextEditingController _listNameController;
  late TextEditingController _spotsController;
  late TextEditingController _waitlistController;
  late TextEditingController _bucketController;
  late TextEditingController _addressController;
  late TextEditingController _guestHostCodeController;

  String? _selectedAddressDescription;
  String? _selectedStateAbbr;
  double? _selectedLat;
  double? _selectedLng;

  DateTime? _selectedDate;
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _initialData;

  bool _isSearchable = true;
  bool _guestHostEnabled = false;

  final String googleApiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? 'MISSING_API_KEY';

  @override
  void initState() {
    super.initState();
    _listNameController = TextEditingController();
    _spotsController = TextEditingController();
    _waitlistController = TextEditingController();
    _bucketController = TextEditingController();
    _addressController = TextEditingController();
    _guestHostCodeController = TextEditingController();
    _fetchListData();
  }

  @override
  void dispose() {
    _listNameController.dispose();
    _spotsController.dispose();
    _waitlistController.dispose();
    _bucketController.dispose();
    _addressController.dispose();
    _guestHostCodeController.dispose();
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
        _addressController.text = _selectedAddressDescription ?? '';
        _selectedStateAbbr = _initialData?['state'];
        _selectedLat = _initialData?['latitude'];
        _selectedLng = _initialData?['longitude'];
        _isSearchable = _initialData?['isSearchable'] ?? true;
        _guestHostEnabled = _initialData?['guestHostEnabled'] ?? false;
        _guestHostCodeController.text = _initialData?['guestHostCode'] ?? '';
        final Timestamp? dateTimestamp = _initialData?['date'] as Timestamp?;
        _selectedDate = dateTimestamp?.toDate();
      } else {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: List not found.'), backgroundColor: Colors.red));
            Navigator.pop(context);
         }
      }
    } catch (e) {
      debugPrint("Error fetching list data: $e");
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
         firstDate: DateTime.now().subtract(const Duration(days: 30)),
         lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
     );
     if (picked != null && picked != _selectedDate) {
         setState(() { _selectedDate = picked; });
     }
  }

  String? _extractStateAbbr(Prediction prediction) {
     if (prediction.terms != null && prediction.terms!.length >= 2) { final stateTerm = prediction.terms![prediction.terms!.length - 2]; if (stateTerm.value != null && stateTerm.value!.length == 2 && RegExp(r'^[a-zA-Z]+$').hasMatch(stateTerm.value!)) return stateTerm.value!.toUpperCase(); }
     if (prediction.structuredFormatting?.secondaryText != null) { final parts = prediction.structuredFormatting!.secondaryText!.split(', '); if (parts.length >= 2) { final statePart = parts[parts.length - 2]; if (statePart.length == 2 && RegExp(r'^[a-zA-Z]+$').hasMatch(statePart)) return statePart.toUpperCase(); } }
     return null;
  }

  Future<String?> _lookupGuestHostUid(String code) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('findUserByHostCode');
      final results = await callable.call({'hostCode': code});
      return results.data['uid'] as String?;
    } catch (e) {
      debugPrint("Error looking up guest host: $e");
      return null;
    }
  }

  Future<void> _updateList() async {
    if (_selectedAddressDescription == null || _selectedAddressDescription!.isEmpty || _selectedStateAbbr == null || _selectedStateAbbr!.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a valid address using the search.'))); return; }
    if (_selectedDate == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a date.'))); return; }
    if (!_formKey.currentState!.validate()) return;
    final user = _auth.currentUser;
    if (user == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Not logged in.'), backgroundColor: Colors.red)); return; }

    setState(() { _isSaving = true; });

    String? guestHostUid;
    if (_guestHostEnabled && _guestHostCodeController.text.isNotEmpty) {
       // Only lookup if code changed
       if (_guestHostCodeController.text.trim() != _initialData?['guestHostCode']) {
          guestHostUid = await _lookupGuestHostUid(_guestHostCodeController.text.trim());
          if (guestHostUid == null) {
             setState(() { _isSaving = false; });
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guest Host Code not found.'), backgroundColor: Colors.red));
             return;
          }
       } else {
          guestHostUid = _initialData?['guestHostUserId'];
       }
    }

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
        'isSearchable': _isSearchable,
        'guestHostEnabled': _guestHostEnabled,
        'guestHostCode': _guestHostEnabled ? _guestHostCodeController.text.trim() : null,
        'guestHostUserId': guestHostUid,
      };
      await _firestore.collection('Lists').doc(widget.listId).update(updatedData);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('List updated successfully!'))); Navigator.pop(context); }
    } catch (e) {
       debugPrint("Error updating list: $e");
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating list: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  Future<void> _clearList() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear List'),
        content: const Text('Are you sure you want to clear all signups from this list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        await _firestore.collection('Lists').doc(widget.listId).update({
          'spots': {},
          'signedUpUserIds': [],
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('List cleared!')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error clearing list'), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildNumberTextField({ required TextEditingController controller, required String label }) {
     return TextFormField(controller: controller, style: const TextStyle(color: Colors.black87), decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: Colors.grey.shade700), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade400)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.blue.shade400, width: 2.0)), counterText: ""), keyboardType: TextInputType.number, inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly], maxLength: 3, validator: (value) { if (value == null || value.isEmpty) return null; final number = int.tryParse(value); if (number == null) return 'Invalid number'; if (number < 0) return 'Cannot be negative'; return null; });
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color buttonColor = Colors.blue.shade600;
    final Color labelColor = Colors.grey.shade800;

    Widget bodyContent;
    if (googleApiKey == 'MISSING_API_KEY') {
       bodyContent = const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('ERROR: GOOGLE_PLACES_API_KEY is missing...', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center)));
    } else {
       bodyContent = Form(
          key: _formKey,
          child: ListView(
             padding: const EdgeInsets.all(16.0),
             children: [
                FadeInDown(duration: const Duration(milliseconds: 500), child: TextFormField(controller: _listNameController, style: const TextStyle(color: Colors.black87), decoration: InputDecoration(labelText: 'List Name', labelStyle: TextStyle(color: labelColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade400)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5))), validator: (v)=>(v==null||v.trim().isEmpty)?'Enter name':null)),
                const SizedBox(height: 16),
                FadeInDown(
                   duration: const Duration(milliseconds: 600),
                   child: GooglePlaceAutoCompleteTextField(
                      textEditingController: _addressController,
                      googleAPIKey: googleApiKey,
                      inputDecoration: InputDecoration(labelText: "Address / Venue", labelStyle: TextStyle(color: labelColor), hintText: "Search Address or Venue", hintStyle: TextStyle(color: Colors.grey.shade500), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade400)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5)), prefixIcon: Icon(Icons.location_on_outlined, color: Colors.grey.shade700)),
                      debounceTime: 400, countries: const ["us"], isLatLngRequired: true,
                      getPlaceDetailWithLatLng: (Prediction prediction) {
                         _addressController.text = prediction.description ?? '';
                         setState(() { _selectedAddressDescription = prediction.description; _selectedLat = double.tryParse(prediction.lat ?? ''); _selectedLng = double.tryParse(prediction.lng ?? ''); _selectedStateAbbr = _extractStateAbbr(prediction); });
                         if (_selectedStateAbbr == null && mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not automatically determine state.'), backgroundColor: Colors.orange)); }
                      },
                      itemClick: (Prediction prediction) { _addressController.text = prediction.description ?? ''; _addressController.selection = TextSelection.fromPosition(TextPosition(offset: prediction.description?.length ?? 0)); },
                   ),
                ),
                const SizedBox(height: 16),
                FadeInDown(
  duration: const Duration(milliseconds: 700),
  child: Card(
    color: Colors.white.withValues(alpha: 0.9),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    elevation: 0,
    child: ListTile(
      leading: Icon(Icons.calendar_today, color: Colors.grey.shade700),
      title: Text('Show Date', style: TextStyle(color: Colors.grey.shade700)),
      subtitle: Text(
        _selectedDate == null
            ? 'Select Date'
            : DateFormat('EEE, MMM d, yyyy').format(_selectedDate!),
        style: TextStyle(
          color: _selectedDate == null ? Colors.grey.shade500 : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () => _selectDate(context),
      trailing: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
    ),
  ),
),
                const SizedBox(height: 16),
                FadeInDown(duration: const Duration(milliseconds: 900), child: _buildNumberTextField(controller: _spotsController, label: 'Number of Regular Spots')),
                const SizedBox(height: 16),
                FadeInDown(duration: const Duration(milliseconds: 1000), child: _buildNumberTextField(controller: _waitlistController, label: 'Number of Waitlist Spots')),
                const SizedBox(height: 16),
                FadeInDown(duration: const Duration(milliseconds: 1100), child: _buildNumberTextField(controller: _bucketController, label: 'Number of Bucket Spots')),
                const SizedBox(height: 24),
                FadeInDown(
                  duration: const Duration(milliseconds: 1200),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.black54),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Searchable by Performers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(_isSearchable ? 'This list will appear in searches.' : 'Only accessible via QR code (Show up, go up)', style: const TextStyle(color: Colors.black45, fontSize: 12)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isSearchable,
                        thumbColor: WidgetStateProperty.resolveWith((states) => Colors.deepPurple),
                        onChanged: (val) => setState(() => _isSearchable = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FadeInDown(
                  duration: const Duration(milliseconds: 1300),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Guest Host', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Text('Allow someone else to host this list temporarily', style: TextStyle(color: Colors.black45, fontSize: 12)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Enable Guest Host'),
                            Switch(
                              value: _guestHostEnabled,
                              onChanged: (val) => setState(() => _guestHostEnabled = val),
                            ),
                          ],
                        ),
                        if (_guestHostEnabled)
                          Padding(
                            padding: const EdgeInsets.only(top: 15.0),
                            child: FadeIn(
                              child: TextFormField(
                                controller: _guestHostCodeController,
                                style: const TextStyle(color: Colors.black87),
                                decoration: InputDecoration(
                                  labelText: 'Guest Host Code',
                                  hintText: 'Enter 6-digit Host Code',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                maxLength: 6,
                                validator: (val) => (_guestHostEnabled && (val == null || val.length != 6)) ? 'Enter 6-digit code' : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _isSaving ? Center(child: CircularProgressIndicator(color: buttonColor)) : ElasticIn(duration: const Duration(milliseconds: 800), child: ElevatedButton(onPressed: _updateList, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: buttonColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))), child: const Text('Save Changes', style: TextStyle(fontSize: 18, color: Colors.white)))),
                const SizedBox(height: 12),
                _isSaving ? const SizedBox() : FadeInUp(duration: const Duration(milliseconds: 800), child: ElevatedButton.icon(onPressed: _clearList, icon: const Icon(Icons.refresh, color: Colors.white), label: const Text('Clear List', style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.red.shade400, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))))),
             ],
          ),
       );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor, elevation: 0, foregroundColor: Colors.white,
        title: const Text('Edit List', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade200, Colors.purple.shade100],
          ),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: appBarColor))
            : bodyContent,
      ),
    );
  }
}
