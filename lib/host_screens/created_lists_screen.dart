// lib/pages/created_lists_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences

// Import necessary screens
import 'list_setup_screen.dart';
import '../role_selection_screen.dart'; // Import RoleSelectionScreen
// import 'show_list_screen.dart'; // Your detail screen

class CreatedListsScreen extends StatelessWidget {
  CreatedListsScreen({Key? key}) : super(key: key);

  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // --- Function to handle switching role ---
  Future<void> _switchRole(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role'); // Clear the saved role

    // Navigate back to RoleSelectionScreen, replacing the current screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
    );
  }
  // --- End Function ---


  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      // This part should ideally not be reached if AuthWrapper is working,
      // but keep as a fallback.
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (Navigator.canPop(context)) {
            Navigator.of(context).pushReplacementNamed('/registration');
         } else {
            Navigator.pushReplacementNamed(context, '/registration');
         }
      });
       return Scaffold(body: Center(child: Text("Redirecting...")));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('My Created Lists (Host)'), // Indicate role in title
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        // --- Add Actions for the Button ---
        actions: [
          Tooltip( // Good practice for IconButton
             message: 'Switch Role',
             child: IconButton(
                icon: Icon(Icons.switch_account),
                onPressed: () => _switchRole(context), // Call the switch role function
             ),
          ),
        ],
        // --- End Actions ---
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Lists')
            .where('userId', isEqualTo: currentUserId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // ... (Existing StreamBuilder logic remains the same)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print("Error fetching lists: ${snapshot.error}");
            return Center(child: Text('Error loading lists. Please try again.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('You haven\'t created any lists yet.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final listData = doc.data() as Map<String, dynamic>?;
              final String docId = doc.id;

              if (listData == null) {
                return ListTile(title: Text('Error loading list data'));
              }

              final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
              final filledSpotsCount = spotsMap.length;
              final regularSpots = (listData['numberOfSpots'] ?? 0) as int;
              final waitlistSpots = (listData['numberOfWaitlistSpots'] ?? 0) as int;
              final bucketSpots = (listData['numberOfBucketSpots'] ?? 0) as int;
              final totalSpots = regularSpots + waitlistSpots + bucketSpots;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: ListTile(
                  title: Text(listData['listName'] ?? 'Unnamed List'),
                  subtitle: Text(listData['venueName'] ?? 'No Venue'),
                  trailing: Text(
                    'Spots: $filledSpotsCount/$totalSpots',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    // TODO: Navigate to your list detail screen (e.g., ShowListScreen)
                    /*
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ShowListScreen(listId: docId),
                      ),
                    );
                    */
                    print('Tapped on list: $docId');
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            // Ensure this navigates to the correct setup screen class name
            MaterialPageRoute(builder: (context) => ListSetupScreen()),
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Create New List',
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
}