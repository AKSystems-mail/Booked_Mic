// lib/host_screens/created_lists_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';

// Import necessary screens
import 'list_setup_screen.dart'; // Keep this for FAB navigation
import '../role_selection_screen.dart';
import 'show_list_screen.dart';
import 'edit_list_screen.dart';
// Removed unused import: import '../registration_screen.dart'; // Not directly used here

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

  Future<void> _showOptionsDialog(BuildContext context, String listId, String listName) async {
     final Color primaryColor = Theme.of(context).primaryColor;
     final Color appBarColor = Colors.blue.shade400;
     await showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
           return AlertDialog(
              backgroundColor: Colors.white.withOpacity(0.95),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text(listName, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
              content: Text('What would you like to do with this list?', style: TextStyle(color: Colors.black87)),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: <Widget>[
                 TextButton.icon(icon: Icon(Icons.edit_outlined, color: appBarColor), label: Text('Edit', style: TextStyle(color: appBarColor)), onPressed: () { Navigator.of(dialogContext).pop(); Navigator.push(context, MaterialPageRoute(builder: (context) => EditListScreen(listId: listId))); }),
                 TextButton.icon(icon: Icon(Icons.visibility_outlined, color: appBarColor), label: Text('Show', style: TextStyle(color: appBarColor)), onPressed: () { Navigator.of(dialogContext).pop(); Navigator.push(context, MaterialPageRoute(builder: (context) => ShowListScreen(listId: listId))); }),
              ],
           );
        }
     );
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    // Use appBarColor for FAB, removed unused fabColor variable
    // final Color fabColor = appBarColor;

    if (currentUserId == null) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
          // Check mounted before navigation
          if (!context.mounted) return;
          // Ensure RegistrationScreen is imported if this path is possible
          // import '../registration_screen.dart'; // Add if needed
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => RoleSelectionScreen()), (Route<dynamic> route) => false); // Go to RoleSelection instead?
       });
       return Scaffold(body: Center(child: Text("Redirecting...")));
    }

    return Scaffold(
      appBar: AppBar(
         backgroundColor: appBarColor, elevation: 0, foregroundColor: Colors.white,
         title: Text('Created Lists'),
         actions: [ Tooltip(message: 'Switch Role', child: IconButton(icon: Icon(Icons.sync_alt, size: 28.0), onPressed: () => _switchRole(context))) ],
      ),
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Colors.blue.shade200, Colors.purple.shade100])),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('Lists').where('userId', isEqualTo: currentUserId).orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: appBarColor));
            if (snapshot.hasError) return Center(child: Text('Error loading lists.', style: TextStyle(color: Colors.red.shade900)));
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('You haven\'t created any lists yet.', style: TextStyle(color: Colors.black54, fontSize: 16)));

            return GridView.builder(
              padding: EdgeInsets.all(12.0),
              itemCount: snapshot.data!.docs.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10.0, mainAxisSpacing: 10.0, childAspectRatio: 0.85),
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final listData = doc.data() as Map<String, dynamic>?;
                final String docId = doc.id;

                if (listData == null) { return FadeInUp(delay: Duration(milliseconds: 100 * index), child: Card(child: Center(child: Text('Error')))); }

                final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
                int filledRegular = 0, filledWaitlist = 0, filledBucket = 0;
                spotsMap.forEach((key, value) { if (value is Map) { if (key.startsWith('W')) filledWaitlist++; else if (key.startsWith('B')) filledBucket++; else if (int.tryParse(key) != null) filledRegular++; } });
                final totalRegular = (listData['numberOfSpots'] ?? 0) as int;
                final totalWaitlist = (listData['numberOfWaitlistSpots'] ?? 0) as int;
                final totalBucket = (listData['numberOfBucketSpots'] ?? 0) as int;

                return FadeInUp(
                  delay: Duration(milliseconds: 100 * index),
                  duration: const Duration(milliseconds: 400),
                  child: Card(
                    color: Colors.white.withOpacity(0.9), elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), clipBehavior: Clip.antiAlias,
                    child: InkWell(
                       borderRadius: BorderRadius.circular(10),
                       onTap: () => _showOptionsDialog(context, docId, listData['listName'] ?? 'Unnamed List'),
                       child: Padding(
                         padding: const EdgeInsets.all(12.0),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(listData['listName'] ?? 'Unnamed List', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis), SizedBox(height: 4), Text(listData['venueName'] ?? 'No Venue', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis) ]),
                             Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ if (totalRegular > 0) Padding(padding: const EdgeInsets.only(top: 4.0), child: Text('Regular: $filledRegular/$totalRegular', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13))), if (totalWaitlist > 0) Padding(padding: const EdgeInsets.only(top: 4.0), child: Text('Waitlist: $filledWaitlist/$totalWaitlist', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13))), if (totalBucket > 0) Padding(padding: const EdgeInsets.only(top: 4.0), child: Text('Bucket: $filledBucket/$totalBucket', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13))) ]),
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
         // --- *** ADDED child argument *** ---
         child: FloatingActionButton(
           onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ListSetupScreen())),
           backgroundColor: appBarColor, // Use appBarColor directly
           foregroundColor: Colors.white,
           tooltip: 'Create New List',
           child: Icon(Icons.add),
         ),
         // --- *** END ADDED child argument *** ---
      ),
    );
  }
}