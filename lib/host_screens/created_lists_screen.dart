// host_screen/created_lists_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart'; // Import animate_do

// Import necessary screens
import 'list_setup_screen.dart';
import '../role_selection_screen.dart';
import 'show_list_screen.dart';
import '../registration_screen.dart';

class CreatedListsScreen extends StatelessWidget {
  CreatedListsScreen({Key? key}) : super(key: key);

  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // --- Function to handle switching role ---
  Future<void> _switchRole(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
    );
  }
  // --- End Function ---

  @override
  Widget build(BuildContext context) {
    // Colors from reference style
    final Color appBarColor = Colors.blue.shade400;
    // Use appBarColor for FAB as well for consistency, or buttonColor if preferred
    final Color fabColor = appBarColor; // Or Colors.blue.shade600;

    // Handle case where user is somehow null
    if (currentUserId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => RegistrationScreen()),
          (Route<dynamic> route) => false,
        );
      });
      return Scaffold(body: Center(child: Text("Redirecting...")));
    }

    return Scaffold(
      appBar: AppBar(
        // Apply reference style
        backgroundColor: appBarColor,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text('Created Lists'),
        actions: [
          Tooltip(
            message: 'Switch Role',
            child: IconButton(
              icon: Icon(Icons.switch_account),
              onPressed: () => _switchRole(context),
            ),
          ),
        ],
      ),
      // Apply gradient background from reference
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Colors.blue.shade200, Colors.purple.shade100],
          ),
        ),
        // StreamBuilder content goes inside the gradient container
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Lists')
              .where('userId', isEqualTo: currentUserId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            // Handle loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Make loading indicator visible on gradient
              return Center(child: CircularProgressIndicator(color: appBarColor));
            }
            // Handle errors
            if (snapshot.hasError) {
              print("Error fetching lists: ${snapshot.error}");
              // Make error text visible
              return Center(child: Text('Error loading lists.', style: TextStyle(color: Colors.red.shade900)));
            }
            // Handle no data case
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              // Make text visible
              return Center(child: Text('You haven\'t created any lists yet.', style: TextStyle(color: Colors.black54, fontSize: 16)));
            }

            // Data is available, build the list view
            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final listData = doc.data() as Map<String, dynamic>?;
                final String docId = doc.id;

                if (listData == null) {
                  // Add animation to error tile as well
                  return FadeInUp(
                     delay: Duration(milliseconds: 100 * index), // Stagger animation
                     child: Card(
                       margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                       child: ListTile(title: Text('Error loading list data')),
                     )
                  );
                }

                // Calculate Filled vs Total Spots
                final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
                final filledSpotsCount = spotsMap.values.whereType<Map>().length;
                final regularSpots = (listData['numberOfSpots'] ?? 0) as int;
                final waitlistSpots = (listData['numberOfWaitlistSpots'] ?? 0) as int;
                final bucketSpots = (listData['numberOfBucketSpots'] ?? 0) as int;
                final totalSpots = regularSpots + waitlistSpots + bucketSpots;

                // Apply animation to each list item Card
                return FadeInUp(
                  delay: Duration(milliseconds: 100 * index), // Stagger animation
                  duration: const Duration(milliseconds: 400), // Control speed
                  child: Card(
                    // Style Card to look good on gradient (optional: add opacity/elevation)
                    color: Colors.white.withOpacity(0.9), // Slightly transparent card
                    elevation: 3,
                    margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0), // Adjust margin
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Match input radius
                    child: ListTile(
                      title: Text(listData['listName'] ?? 'Unnamed List', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(listData['venueName'] ?? 'No Venue'),
                      trailing: Text(
                        'Spots: $filledSpotsCount/$totalSpots',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ShowListScreen(listId: docId),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      // Apply animation and style to FAB
      floatingActionButton: FadeInUp( // Animate FAB
        delay: Duration(milliseconds: 500), // Delay slightly after list items
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ListSetupScreen()),
            );
          },
          // Apply reference style
          backgroundColor: fabColor,
          foregroundColor: Colors.white,
          tooltip: 'Create New List',
          child: Icon(Icons.add),
        ),
      ),
    );
  }
}