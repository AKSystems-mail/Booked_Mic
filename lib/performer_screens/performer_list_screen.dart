// lib/performer_screens/performer_list_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart'; 
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform; 

// Import necessary screens
import '../role_selection_screen.dart';
import 'signup_screen.dart';
import '../registration_screen.dart';
import '../widgets/qr_scanner_overlay.dart';
import '../services/notification_service.dart';

class PerformerListScreen extends StatefulWidget {
  const PerformerListScreen({super.key});

  static bool autoScanTrigger = false;

  @override
  State<PerformerListScreen> createState() => _PerformerListScreenState();
}

class _PerformerListScreenState extends State<PerformerListScreen> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedSearchState;
    static const String _lastSelectedStateKey = 'last_selected_search_state'; 
  final List<String> usStates = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY', 'DC'
  ];

  @override
  void initState() {
    super.initState();
    _loadLastSelectedState();
    if (PerformerListScreen.autoScanTrigger) {
      PerformerListScreen.autoScanTrigger = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scanQrCode();
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _switchRole(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  Future<void> _loadLastSelectedState() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastState = prefs.getString(_lastSelectedStateKey);
    if (lastState != null && mounted) {
       // setState(() { _selectedSearchState = lastState; });
    }
  }

  Future<void> _saveLastSelectedState(String state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSelectedStateKey, state);
  }

  Future<void> _showStateSearchDialog() async {
    final prefs = await SharedPreferences.getInstance();
    String? previouslySelectedState = prefs.getString(_lastSelectedStateKey);

    String searchQuery = '';
    List<String> filteredStates = List.from(usStates);

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (searchQuery.isEmpty) {
              filteredStates = List.from(usStates);
            } else {
              filteredStates = usStates
                  .where((s) => s.toLowerCase().contains(searchQuery.toLowerCase()))
                  .toList();
            }

            return AlertDialog(
              backgroundColor: Colors.white.withValues(alpha: 0.98),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text('Search State', style: TextStyle(color: Theme.of(context).primaryColor)),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Type to search states...', 
                          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            searchQuery = value;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: filteredStates.isEmpty
                          ? Center(child: Text('No states found for "$searchQuery"'))
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredStates.length,
                              itemBuilder: (context, index) {
                                final state = filteredStates[index];
                                bool isPreviouslySelected = state == previouslySelectedState;
                                return ListTile(
                                  title: Text(
                                    state,
                                    style: TextStyle(
                                      fontWeight: isPreviouslySelected ? FontWeight.bold : FontWeight.w500,
                                      color: isPreviouslySelected ? Theme.of(context).primaryColor : Colors.black87,
                                    ),
                                  ),
                                  tileColor: isPreviouslySelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  onTap: () => Navigator.of(dialogContext).pop(state),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      if (result != _selectedSearchState) {
        setState(() {
          _selectedSearchState = result;
        });
      }
      await _saveLastSelectedState(result);
    }
  }

  void _toggleSearch() {
    if (_selectedSearchState == null) {
      _showStateSearchDialog();
    } else {
      setState(() {
        _selectedSearchState = null;
      });
    }
  }

  Future<void> _launchMaps(String address) async {
    if (address.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address is not available.')),
        );
      }
      return;
    }

    String query = Uri.encodeComponent(address);
    Uri? platformSpecificUri;
    bool launchedSuccessfully = false;

    // Use standard platform schemes
    if (Platform.isAndroid) {
      platformSpecificUri = Uri.parse('geo:0,0?q=$query');
    } else if (Platform.isIOS) {
      platformSpecificUri = Uri.parse('maps://?q=$query'); // Corrected Apple Maps scheme
    }

    // Try to open the native map application directly
    if (platformSpecificUri != null) {
      try {
        // Direct launch attempt bypassing canLaunchUrl
        launchedSuccessfully = await launchUrl(
          platformSpecificUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (e) {
        debugPrint("Error launching native maps app: $e");
      }
    }

    // Fallback: If native deep link fails or is unsupported, launch web maps
    if (!launchedSuccessfully) {
      Uri fallbackUri;
      if (Platform.isIOS) {
        // Universal web link that Apple devices intercept to open Apple Maps
        fallbackUri = Uri.parse('https://maps.apple.com/?q=$query');
      } else {
        // Universal web link for Google Maps on Android
        fallbackUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
      }

      try {
        launchedSuccessfully = await launchUrl(
          fallbackUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        debugPrint("Error launching web fallback maps: $e");
      }
    }

    if (!launchedSuccessfully) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps app or website.')),
        );
      }
    }
  }

  Widget _buildListSection(BuildContext context, String title, List<DocumentSnapshot> docs, bool showSpotNumber) {
     if (docs.isEmpty) return const SizedBox.shrink();
     
     return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Padding(
             padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
             child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black.withValues(alpha: 0.8))),
           ),
           ListView.builder(
             shrinkWrap: true,
             physics: const NeverScrollableScrollPhysics(),
             itemCount: docs.length,
             itemBuilder: (context, index) {
               final doc = docs[index];
               final listData = doc.data() as Map<String, dynamic>? ?? {};
               final String docId = doc.id;
               String displayStatus = "In Bucket Draw";
               bool isOver = false;

               final Timestamp? showTimestamp = listData['date'] as Timestamp?;
               String formattedDate = '';
               if (showTimestamp != null) {
                 formattedDate = DateFormat('EEE, MMM d').format(showTimestamp.toDate());
               }

               if (showSpotNumber) {
                  displayStatus = "Unknown Spot";
                  final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
                  spotsMap.forEach((key, value) {
                    if (value is Map && value['userId'] == currentUserId) {
                      displayStatus = "Spot: $key";
                      isOver = value['isOver'] ?? false;
                    }
                  });
               }

               String addressText = listData['address'] ?? 'No Address Provided';

               return FadeInUp(
                 delay: Duration(milliseconds: 100 * index),
                 duration: const Duration(milliseconds: 400),
                 child: Card(
                   color: Colors.white.withValues(alpha: 0.9),
                   elevation: 3, margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                   child: ListTile(
                     title: Text(
                        listData['listName'] ?? 'Unnamed List',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: isOver ? TextDecoration.lineThrough : TextDecoration.none,
                        ),
                        overflow: TextOverflow.ellipsis,
                     ),
                     subtitle: Row(
                       children: [
                         Expanded(
                           child: Text(
                             addressText,
                             overflow: TextOverflow.ellipsis,
                           ),
                         ),
                         if (addressText != 'No Address Provided' && addressText.trim().isNotEmpty)
                           Padding(
                             padding: const EdgeInsets.only(left: 8.0),
                             child: IconButton(
                               icon: Icon(Icons.directions_outlined, color: Theme.of(context).primaryColor),
                               iconSize: 22.0,
                               padding: EdgeInsets.zero,
                               constraints: const BoxConstraints(),
                               tooltip: 'Get Directions',
                               onPressed: () => _launchMaps(addressText),
                             ),
                           ),
                       ],
                     ),
                     trailing: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       crossAxisAlignment: CrossAxisAlignment.end,
                       children: <Widget>[
                         if (formattedDate.isNotEmpty)
                           Text(
                             formattedDate,
                             style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                           ),
                         if (formattedDate.isNotEmpty && displayStatus.isNotEmpty)
                           const SizedBox(height: 4.0),
                         Text(
                           displayStatus,
                           style: TextStyle(
                             fontStyle: !showSpotNumber ? FontStyle.italic : FontStyle.normal,
                             color: Colors.grey.shade700,
                             fontSize: 12,
                           ),
                         ),
                       ],
                     ),
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SignupScreen(listId: docId))),
                   ),
                 ),
               );
             },
           ),
        ],
     );
  }

  Widget _buildMySignupsView() {
    if (currentUserId == null) return Center(child: Text("Not logged in.", style: TextStyle(color: Colors.black54)));

    final onListStream = _firestore
        .collection('Lists')
        .where('signedUpUserIds', arrayContains: currentUserId)
        .orderBy('date', descending: false)
        .snapshots();

    final bucketSignupsStream = _firestore
        .collectionGroup('bucketSignups')
        .where('userId', isEqualTo: currentUserId)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.only(bottom: 80.0),
      children: [
        StreamBuilder<QuerySnapshot>(
            stream: onListStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return Padding(padding: const EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator(color: Colors.blue.shade600)));
              }
              if (snapshot.hasError) {
                return Padding(padding: const EdgeInsets.all(16.0), child: Center(child: Text('Error loading lists: ${snapshot.error}', style: TextStyle(color: Colors.red.shade900))));
              }
              return _buildListSection(context, "Lists You're On", snapshot.data?.docs ?? [], true);
            }),
        StreamBuilder<QuerySnapshot>(
            stream: bucketSignupsStream,
            builder: (context, bucketSnapshot) {
              if (bucketSnapshot.connectionState == ConnectionState.waiting && !bucketSnapshot.hasData) {
                return Padding(padding: const EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator(color: Colors.blue.shade600)));
              }
              if (bucketSnapshot.hasError) {
                return Padding(padding: const EdgeInsets.all(16.0), child: Center(child: Text('Error loading bucket signups: ${bucketSnapshot.error}', style: TextStyle(color: Colors.red.shade900))));
              }
              if (!bucketSnapshot.hasData || bucketSnapshot.data!.docs.isEmpty) return const SizedBox.shrink();

              final List<String> bucketListIds = bucketSnapshot.data!.docs
                  .map((doc) => doc.reference.parent.parent?.id)
                  .where((id) => id != null)
                  .cast<String>()
                  .toSet()
                  .toList();

              if (bucketListIds.isEmpty) return const SizedBox.shrink();

              return FutureBuilder<List<DocumentSnapshot>>(
                  future: Future.wait(bucketListIds.map((id) => _firestore.collection('Lists').doc(id).get())),
                  builder: (context, listDocsSnapshot) {
                    if (listDocsSnapshot.connectionState == ConnectionState.waiting && !listDocsSnapshot.hasData) {
                      return Padding(padding: const EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator(color: Colors.blue.shade600)));
                    }
                    if (listDocsSnapshot.hasError) {
                      return Padding(padding: const EdgeInsets.all(16.0), child: Center(child: Text('Error loading bucket list details: ${listDocsSnapshot.error}', style: TextStyle(color: Colors.red.shade900))));
                    }
                    if (!listDocsSnapshot.hasData || listDocsSnapshot.data!.isEmpty) return const SizedBox.shrink();

                    final validListDocs = listDocsSnapshot.data!.where((doc) => doc.exists).toList();
                    validListDocs.sort((a, b) {
                      Timestamp? dateA = (a.data() as Map<String, dynamic>?)?['date'] as Timestamp?;
                      Timestamp? dateB = (b.data() as Map<String, dynamic>?)?['date'] as Timestamp?;
                      if (dateA == null && dateB == null) return 0;
                      if (dateA == null) return 1;
                      if (dateB == null) return -1;
                      return dateA.compareTo(dateB);
                    });

                    return _buildListSection(context, "Buckets You're In", validListDocs, false);
                  });
            }),
      ],
    );
  }

  Widget _buildSearchResultsBasedOnState(String state) {
    return StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('Lists')
            .where('state', isEqualTo: state.toUpperCase())
            .where('isSearchable', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: Colors.blue.shade600));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error searching lists: ${snapshot.error}', style: TextStyle(color: Colors.red.shade900)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No open lists found for state "$state".', style: const TextStyle(color: Colors.black54, fontSize: 16)));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final listData = doc.data() as Map<String, dynamic>? ?? {};
              final String docId = doc.id;

              final Timestamp? showTimestamp = listData['date'] as Timestamp?;
              String formattedDate = '';
              if (showTimestamp != null) {
                formattedDate = DateFormat('EEE, MMM d').format(showTimestamp.toDate());
              }

              final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
              final filledSpotsCount = spotsMap.values.whereType<Map>().length;
              final regularSpots = (listData['numberOfSpots'] ?? 0) as int;
              final waitlistSpots = (listData['numberOfWaitlistSpots'] ?? 0) as int;
              int totalDefinedSpots = regularSpots + waitlistSpots;

              return FadeInUp(
                delay: Duration(milliseconds: 100 * index),
                duration: const Duration(milliseconds: 400),
                child: Card(
                  color: Colors.white.withValues(alpha: 0.9),
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(listData['listName'] ?? 'Unnamed List', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        ),
                        if (formattedDate.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(formattedDate, style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500)),
                          ),
                      ],
                    ),
                    subtitle: Text(listData['address'] ?? 'No Address Provided', overflow: TextOverflow.ellipsis),
                    trailing: Text('Open Spots: $filledSpotsCount/$totalDefinedSpots'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SignupScreen(listId: docId))),
                  ),
                ),
              );
            },
          );
        });
  }

  Future<void> _deleteSignupLocally(String listId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> currentSignups = prefs.getStringList('user_signups') ?? [];
    currentSignups.remove(listId);
    await prefs.setStringList('user_signups', currentSignups);
    if (mounted) setState(() {});
  }

  Future<void> _scanQrCode() async {
    var status = await Permission.camera.request();
    if (status.isGranted) {
      if (!mounted) return;
      final String? result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QrScannerOverlay()),
      );
      if (result != null && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => SignupScreen(listId: result)));
      }
    } else if (status.isPermanentlyDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camera permission permanently denied. Please enable it in settings.')));
      await openAppSettings();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camera permission is required to scan QR codes.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color fabColor = Colors.blue.shade700;
    if (currentUserId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const RegistrationScreen()), (route) => false);
        }
      });
      return const Scaffold(body: Center(child: Text("Redirecting...")));
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: appBarColor,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Booked Mic', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text(
              _selectedSearchState == null ? 'My Signups' : 'Open Lists: $_selectedSearchState',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Tooltip(
              message: _selectedSearchState == null ? 'Search by State' : 'Clear Search ($_selectedSearchState)',
              child: IconButton(
                  icon: Icon(_selectedSearchState == null ? Icons.search : Icons.search_off),
                  onPressed: _toggleSearch)),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              foregroundColor: Colors.white,
              backgroundColor: Colors.blue.shade800,
              shape: const StadiumBorder(),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.sync_alt, size: 16),
            label: const Text('Switch Role', style: TextStyle(fontSize: 12)),
            onPressed: () => _switchRole(context),
          ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Colors.blue.shade200, Colors.purple.shade100])),
            child: _selectedSearchState == null ? _buildMySignupsView() : _buildSearchResultsBasedOnState(_selectedSearchState!),
          ),
          // --- REAL-TIME QUEUE STATUS BANNER ---
          ValueListenableBuilder<Map<String, int?>>(
            valueListenable: NotificationService().lastNotifiedPositionNotifier,
            builder: (context, positions, child) {
              if (positions.isEmpty) return const SizedBox.shrink();
              
              // Find the closest position among all signed-up lists
              String? listId;
              int? position;
              
              positions.forEach((key, val) {
                if (val != null && (position == null || val < position!)) {
                  position = val;
                  listId = key;
                }
              });

              if (position == null) return const SizedBox.shrink();

              String message = position == 0 
                  ? "YOU ARE UP NEXT!" 
                  : (position == 1 ? "1 person ahead of you" : "$position people ahead of you");

              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FadeInDown(
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: position == 0 ? Colors.orange.shade800 : Colors.blue.shade800,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_active, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Clear the notification for this specific list locally
                            final nextMap = Map<String, int?>.from(NotificationService().lastNotifiedPositionNotifier.value);
                            nextMap.remove(listId);
                            NotificationService().lastNotifiedPositionNotifier.value = nextMap;
                          },
                          child: const Text("GOT IT", style: TextStyle(color: Colors.white, decoration: TextDecoration.underline, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FadeInUp(
        delay: const Duration(milliseconds: 600),
        child: FloatingActionButton(
          onPressed: _scanQrCode,
          backgroundColor: fabColor,
          foregroundColor: Colors.white,
          tooltip: 'Scan List QR Code',
          child: const Icon(Icons.qr_code_scanner),
        ),
      ),
    );
  }
}
