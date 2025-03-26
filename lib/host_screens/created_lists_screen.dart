// host_screens/created_lists_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/show.dart';
import 'package:myapp/providers/firestore_provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import 'edit_list_screen.dart';
import 'list_setup_screen.dart';
import '../role_selection_screen.dart';
import 'show_list_screen.dart'; // Ensure this import is present

class CreatedListsScreen extends StatelessWidget {
  const CreatedListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Created Lists'),
        backgroundColor: Colors.blue.shade400,
        elevation: 0.0,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (BuildContext context) => MyApp(),
                  ),
                  (route) => false,
                );
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                );
              },
              icon: const Icon(Icons.compare_arrows, color: Colors.white),
              label: const Text('Switch Role', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
            body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Colors.blue.shade200, Colors.purple.shade100],
          ),
        ),
        child: Consumer<FirestoreProvider>(
          builder: (context, firestoreProvider, _) {
            return StreamBuilder<List<Show>>(
              stream: firestoreProvider.getShows(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print('Error: ${snapshot.error}');
                  return const Center(child: Text('Error loading shows.'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  print('No data found');
                  return const Center(child: Text('No shows created yet.'));
                }

                print('Data: ${snapshot.data}');
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  padding: const EdgeInsets.all(16.0),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (BuildContext context, int index) {
                    final show = snapshot.data![index];
                    final formattedDate = DateFormat('MM-dd-yyyy').format(show.date);

                    return FadeInUp(
                      duration: Duration(milliseconds: 500 + index * 100),
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text(show.showName),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context); // Close the dialog
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EditListScreen(showId: show.id!),
                                          ),
                                        );
                                      },
                                      child: const Text('Edit'),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context); // Close the dialog
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ShowListScreen(showId: show.id!),
                                          ),
                                        );
                                      },
                                      child: const Text('Open'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        child: Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(show.showName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                const SizedBox(height: 8),
                                Text(formattedDate, style: const TextStyle(color: Colors.grey)),
                                const SizedBox(height: 8),
                                // Removed QR code widget
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: ElasticIn(
        duration: const Duration(milliseconds: 800),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ListSetupScreen()),
            );
          },
          backgroundColor: Colors.blue.shade600,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}