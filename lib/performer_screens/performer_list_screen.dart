// lib/pages/performer_list_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';

// Import necessary screens
import '../role_selection_screen.dart';
import 'signup_screen.dart';

class PerformerListScreen extends StatefulWidget {
  PerformerListScreen({Key? key}) : super(key: key);

  @override
  _PerformerListScreenState createState() => _PerformerListScreenState();
}

class _PerformerListScreenState extends State<PerformerListScreen> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedSearchState; // Holds the selected state abbreviation, null if showing "My Signups"

  final List<String> usStates = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY', 'DC'
  ];

  Future<void> _switchRole(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
    );
  }

  // --- Dialog for State Selection ---
  Future<void> _showStateSearchDialog() async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final Color primaryColor = Theme.of(context).primaryColor;
        final Color appBarColor = Colors.blue.shade400;

        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          // Updated Title
          title: Text('Search by State', style: TextStyle(color: primaryColor)),
          content: Container(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            // Removed the "Show My Signups" ListTile and Divider
            child: ListView.builder( // Directly show the state list
              shrinkWrap: true,
              itemCount: usStates.length,
              itemBuilder: (context, index) {
                final state = usStates[index];
                return ListTile(
                  title: Text(state, style: TextStyle(fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.of(context).pop(state); // Pop dialog, returning selected state
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: appBarColor)),
              onPressed: () {
                Navigator.of(context).pop(); // Pop dialog without returning a value (no change)
              },
            ),
          ],
        );
      },
    );

    // Update state only if a state was actually selected from the dialog
    if (result != null && result != _selectedSearchState) {
       setState(() {
          _selectedSearchState = result;
       });
    }
  }

  // --- Toggle Search State ---
  // Called when the search icon is pressed
  void _toggleSearch() {
     if (_selectedSearchState == null) {
        // If not currently searching, open the dialog to select a state
        _showStateSearchDialog();
     } else {
        // If currently searching, clear the search to show "My Signups"
        setState(() {
           _selectedSearchState = null;
        });
     }
  }


  // --- Widget for Signed-up Lists --- (No changes needed in this function)
  Widget _buildSignedUpLists() {
    if (currentUserId == null) return Center(child: Text("Not logged in.", style: TextStyle(color: Colors.black54)));
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('Lists').where('signedUpUserIds', arrayContains: currentUserId).orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: Colors.blue.shade600));
        if (snapshot.hasError) return Center(child: Text('Error loading your lists: ${snapshot.error}', style: TextStyle(color: Colors.red.shade900)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('You haven\'t signed up for any lists yet.', style: TextStyle(color: Colors.black54, fontSize: 16)));
        return ListView.builder(
          padding: EdgeInsets.only(top: 8.0, bottom: 80.0),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final listData = doc.data() as Map<String, dynamic>? ?? {};
            final String docId = doc.id;
            String mySpot = "Unknown Spot";
            final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
            spotsMap.forEach((key, value) { if (value is Map && value['userId'] == currentUserId) mySpot = key; });
            return FadeInUp(
              delay: Duration(milliseconds: 100 * index), duration: const Duration(milliseconds: 400),
              child: Card(
                color: Colors.white.withOpacity(0.9), elevation: 3, margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  title: Text(listData['listName'] ?? 'Unnamed List', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(listData['venueName'] ?? 'No Venue'),
                  trailing: Text("Your Spot: $mySpot"),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SignupScreen(listId: docId))),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Widget for State Search Results --- (No changes needed in this function)
  Widget _buildSearchResultsBasedOnState(String state) {
     return StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('Lists').where('state', isEqualTo: state.toUpperCase()).orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: Colors.blue.shade600));
           if (snapshot.hasError) return Center(child: Text('Error searching lists: ${snapshot.error}', style: TextStyle(color: Colors.red.shade900)));
           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('No open lists found for state "$state".', style: TextStyle(color: Colors.black54, fontSize: 16)));
           return ListView.builder(
             padding: EdgeInsets.only(top: 8.0, bottom: 80.0),
             itemCount: snapshot.data!.docs.length,
             itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final listData = doc.data() as Map<String, dynamic>? ?? {};
                final String docId = doc.id;
                final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
                final filledSpotsCount = spotsMap.values.whereType<Map>().length;
                final regularSpots = (listData['numberOfSpots'] ?? 0) as int;
                final waitlistSpots = (listData['numberOfWaitlistSpots'] ?? 0) as int;
                final bucketSpots = (listData['numberOfBucketSpots'] ?? 0) as int;
                final totalSpots = regularSpots + waitlistSpots + bucketSpots;
                return FadeInUp(
                   delay: Duration(milliseconds: 100 * index), duration: const Duration(milliseconds: 400),
                   child: Card(
                     color: Colors.white.withOpacity(0.9), elevation: 3, margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                     child: ListTile(
                       title: Text(listData['listName'] ?? 'Unnamed List', style: TextStyle(fontWeight: FontWeight.bold)),
                       subtitle: Text(listData['venueName'] ?? 'No Venue'),
                       trailing: Text('Spots: $filledSpotsCount/$totalSpots'),
                       onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SignupScreen(listId: docId))),
                     ),
                   ),
                );
             },
           );
        }
     );
  }


  @override
  Widget build(BuildContext context) {
     final Color appBarColor = Colors.blue.shade400;
     final Color fabColor = appBarColor;

     if (currentUserId == null) { /* ... Fallback redirect ... */ }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(_selectedSearchState == null ? 'My Signups' : 'Open Lists: $_selectedSearchState'),
        actions: [
          // State Search Button (Toggle)
          Tooltip(
            // Updated Tooltip
            message: _selectedSearchState == null ? 'Search by State' : 'Clear Search ($_selectedSearchState)',
            child: IconButton(
              // Updated Icon
              icon: Icon(Icons.search),
              // Updated onPressed to use toggle function
              onPressed: _toggleSearch,
            ),
          ),
          // Switch Role Button
          Tooltip(message: 'Switch Role', child: IconButton(icon: Icon(Icons.switch_account), onPressed: () => _switchRole(context))),
        ],
      ),
      body: Container(
         width: double.infinity,
         height: double.infinity,
         decoration: BoxDecoration(
           gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Colors.blue.shade200, Colors.purple.shade100]),
         ),
         child: _selectedSearchState == null
             ? _buildSignedUpLists()
             : _buildSearchResultsBasedOnState(_selectedSearchState!),
      ),
      floatingActionButton: FadeInUp(
         delay: Duration(milliseconds: 600),
         child: FloatingActionButton(
           onPressed: () { /* TODO: Implement QR Code Scanning */ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('QR Code Scan not implemented yet.'))); },
           backgroundColor: fabColor,
           foregroundColor: Colors.white,
           tooltip: 'Scan List QR Code',
           child: Icon(Icons.qr_code_scanner),
         ),
      ),
    );
  }
}