// lib/performer_screens/nearby_mics_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'signup_screen.dart';

class NearbyMicsScreen extends StatefulWidget {
  const NearbyMicsScreen({super.key});

  @override
  State<NearbyMicsScreen> createState() => _NearbyMicsScreenState();
}

class _NearbyMicsScreenState extends State<NearbyMicsScreen> {
  String? _userState;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserState();
  }

  Future<void> _loadUserState() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to GA if none selected, or we could request location
    setState(() {
      _userState = prefs.getString('last_selected_search_state') ?? 'GA';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Booked Mic', style: TextStyle(fontSize: 12, color: Colors.white70)),
            const Text('Nearby Open Mics', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade200, Colors.purple.shade100],
          ),
        ),
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Lists')
                  .where('state', isEqualTo: _userState)
                  .where('isSearchable', isEqualTo: true)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading mics.'));
                }

                // Filter for only lists with open spots (Regular, Waitlist, or Bucket)
                final openMics = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final spotsMap = data['spots'] as Map<String, dynamic>? ?? {};
                  final filledSpotsCount = spotsMap.values.where((v) => v is Map && v.isNotEmpty).length;
                  final regularSpots = (data['numberOfSpots'] ?? 0) as int;
                  final waitlistSpots = (data['numberOfWaitlistSpots'] ?? 0) as int;
                  final bucketSpots = (data['numberOfBucketSpots'] ?? 0) as int;
                  return filledSpotsCount < (regularSpots + waitlistSpots + bucketSpots);
                }).toList();

                if (openMics.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text(
                        'No open mics found in $_userState with available spots.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: openMics.length,
                  itemBuilder: (context, index) {
                    final doc = openMics[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    final Timestamp? date = data['date'] as Timestamp?;
                    final String formattedDate = date != null ? DateFormat('EEE, MMM d').format(date.toDate()) : '';

                    return FadeInUp(
                      delay: Duration(milliseconds: 100 * index),
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.white.withValues(alpha: 0.9),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(data['listName'] ?? 'Unnamed Mic', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(data['address'] ?? 'No Address'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.event, size: 14, color: Colors.blue.shade700),
                                  const SizedBox(width: 4),
                                  Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ],
                          ),
                          trailing: Icon(Icons.chevron_right, color: Colors.blue.withValues(alpha: 0.5)),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SignupScreen(listId: doc.id))),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      ),
    );
  }
}
