//host_screens/show_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/show.dart';
import 'package:myapp/providers/firestore_provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

class ShowListScreen extends StatefulWidget {
  final String showId;

  const ShowListScreen({super.key, required this.showId});

  @override
  _ShowListScreenState createState() => _ShowListScreenState();
}

class _ShowListScreenState extends State<ShowListScreen> {
  void _addNameDialog(int index) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Name'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Enter name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  Provider.of<FirestoreProvider>(context, listen: false)
                      .addNameToSpot(widget.showId, index, nameController.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickBucketName(int index) async {
    final firestoreProvider =
        Provider.of<FirestoreProvider>(context, listen: false);
    final List<String> bucketNames =
        await firestoreProvider.getBucketNames(widget.showId);

    if (bucketNames.isEmpty) {
      return;
    }

    final randomName = (bucketNames.toList()..shuffle()).first;
    firestoreProvider.addNameToSpot(widget.showId, index, randomName);
    firestoreProvider.removeBucketName(widget.showId, randomName);
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Name'),
          content: const Text('Are you sure you want to delete this name?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Provider.of<FirestoreProvider>(context, listen: false)
                    .removeNameFromSpot(widget.showId, index);
                Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Show List', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0.0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                // Implement QR code download functionality
              },
              icon: const Icon(Icons.download, color: Colors.white),
              label: const Text('Download QR Code',
                  style: TextStyle(color: Colors.white)),
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
            colors: [Colors.black, Colors.grey.shade800],
          ),
        ),
        child: Consumer<FirestoreProvider>(
          builder: (context, firestoreProvider, _) {
            return StreamBuilder<Show>(
              stream: firestoreProvider.getShow(widget.showId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading shows.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: Text('Show not found.'));
                }

                final show = snapshot.data!;
                final formattedDate =
                    DateFormat('MM-dd-yyyy').format(show.date);

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Text(show.showName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                    color: Colors.white)),
                            const SizedBox(height: 8),
                            Text(formattedDate,
                                style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ReorderableListView.builder(
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            firestoreProvider.reorderSpots(
                                widget.showId, oldIndex, newIndex);
                          },
                          itemCount: show.spots + show.waitList.length,
                          itemBuilder: (context, index) {
                            if (index < show.spots) {
                              final spot = index < show.spotsList.length
                                  ? show.spotsList[index] : null;

                              return FadeInUp(
                                key: ValueKey(index),
                                duration: Duration(milliseconds: 500 + index * 100),
                                child: Card(
                                  color: Colors.transparent,
                                  elevation: 5,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15)),
                                  child: ListTile(
                                    leading: Text('${index + 1}.',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 20)),
                                    title: Center(
                                      child: Text(spot?.name ?? 'Empty Spot',
                                          style: const TextStyle(
                                              color: Colors.white)),
                                    ),
                                    subtitle: Center(
                                      child: Text(spot?.type ?? '',
                                          style: const TextStyle(
                                              color: Colors.white)),
                                    ),
                                    trailing: spot != null
                                        ? IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.white),
                                            onPressed: () {
                                              _confirmDelete(index);
                                            },
                                          )
                                        : null,
                                    onTap: () {
                                      if (spot != null) {
                                        if (spot.type == 'Reserved') {
                                          _addNameDialog(index);
                                        } else if (spot.type == 'Bucket') {
                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              return AlertDialog(
                                                title: const Text(
                                                    'Pick name for bucket spot?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.of(context)
                                                          .pop();
                                                    },
                                                    child:
                                                        const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.of(context)
                                                          .pop();
                                                      _pickBucketName(index);
                                                    },
                                                    child:
                                                        const Text('Pick'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        }
                                      } else {
                                        _addNameDialog(index);
                                      }
                                    },
                                  ),
                                ),
                              );
                            } else {
                              final waitListIndex = index - show.spots;
                                if (waitListIndex < show.waitList.length) {
                                    final waitListSpot = show.waitList[waitListIndex];
                                    return Card(
                                        child: ListTile(
                                            key: ValueKey('$waitListIndex'),
                                            title: Text(waitListSpot.name),
                                        ),
                                    );
                                } else {
                                    return Container();
                                }
                              }
                          },
                        ),
                      ),
                    ],
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