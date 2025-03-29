// lib/host_screens/created_lists_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';

// Import necessary screens
import 'list_setup_screen.dart';
import '../role_selection_screen.dart';
import 'show_list_screen.dart';
import '../registration_screen.dart';

class CreatedListsScreen extends StatelessWidget {
  CreatedListsScreen({Key? key}) : super(key: key);

  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _switchRole(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color fabColor = appBarColor;

    if (currentUserId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
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
         backgroundColor: appBarColor, elevation: 0, foregroundColor: Colors.white,
         title: Text('Created Lists'),
         actions: [ Tooltip(message: 'Switch Role', child: IconButton(icon: Icon(Icons.switch_account), onPressed: () => _switchRole(context)))],
      ),
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(
           gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Colors.blue.shade200, Colors.purple.shade100]),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('Lists').where('userId', isEqualTo: currentUserId).orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: appBarColor));
            if (snapshot.hasError) return Center(child: Text('Error loading lists.', style: TextStyle(color: Colors.red.shade900)));
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('You haven\'t created any lists yet.', style: TextStyle(color: Colors.black54, fontSize: 16)));

            return ListView.builder(
              padding: EdgeInsets.only(top: 8.0, bottom: 80.0),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final listData = doc.data() as Map<String, dynamic>?;
                final String docId = doc.id;

                if (listData == null) {
                   return FadeInUp(delay: Duration(milliseconds: 100 * index), child: Card(margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0), child: ListTile(title: Text('Error loading list data'))));
                }

                // --- Calculate Filled Counts for Each Type ---
                final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
                int filledRegular = 0;
                int filledWaitlist = 0;
                int filledBucket = 0;

                spotsMap.forEach((key, value) {
                   if (value is Map) { // Only count actual performer signups
                      if (key.startsWith('W')) filledWaitlist++;
                      else if (key.startsWith('B')) filledBucket++;
                      else if (int.tryParse(key) != null) filledRegular++;
                   }
                });

                final totalRegular = (listData['numberOfSpots'] ?? 0) as int;
                final totalWaitlist = (listData['numberOfWaitlistSpots'] ?? 0) as int;
                final totalBucket = (listData['numberOfBucketSpots'] ?? 0) as int;
                // --- End Calculation ---

                // Apply animation to each list item Card
                return FadeInUp(
                  delay: Duration(milliseconds: 100 * index),
                  duration: const Duration(milliseconds: 400),
                  child: Card(
                    color: Colors.white.withOpacity(0.9),
                    elevation: 3,
                    margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    // Use InkWell for onTap effect on the Card
                    child: InkWell(
                       borderRadius: BorderRadius.circular(10),
                       onTap: () {
                         // Navigate to ShowListScreen using listId
                         Navigator.push(context, MaterialPageRoute(builder: (context) => ShowListScreen(listId: docId)));
                       },
                       child: Padding(
                         padding: const EdgeInsets.all(16.0),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             // List Name (Larger)
                             Text(
                               listData['listName'] ?? 'Unnamed List',
                               style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18), // Adjusted style
                             ),
                             SizedBox(height: 4),
                             // Venue Name (Smaller)
                             Text(
                               listData['venueName'] ?? 'No Venue',
                               style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54), // Adjusted style
                             ),
                             SizedBox(height: 12),
                             // Counts Section
                             if (totalRegular > 0)
                               Padding(
                                 padding: const EdgeInsets.only(top: 4.0),
                                 child: Text('Regular Spots: $filledRegular/$totalRegular', style: TextStyle(fontWeight: FontWeight.w500)),
                               ),
                             if (totalWaitlist > 0)
                               Padding(
                                 padding: const EdgeInsets.only(top: 4.0),
                                 child: Text('Waitlist Spots: $filledWaitlist/$totalWaitlist', style: TextStyle(fontWeight: FontWeight.w500)),
                               ),
                             if (totalBucket > 0)
                               Padding(
                                 padding: const EdgeInsets.only(top: 4.0),
                                 child: Text('Bucket Spots: $filledBucket/$totalBucket', style: TextStyle(fontWeight: FontWeight.w500)),
                               ),
                           ],
                         ),
                       ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FadeInUp(
         delay: Duration(milliseconds: 500),
         child: FloatingActionButton(
           onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ListSetupScreen())),
           backgroundColor: fabColor, foregroundColor: Colors.white,
           tooltip: 'Create New List', child: Icon(Icons.add),
         ),
      ),
    );
  }
}