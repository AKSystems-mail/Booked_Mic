//host_screens/list_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:flutter_spinbox/flutter_spinbox.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/models/show.dart';
import 'package:myapp/host_screens/created_lists_screen.dart';
class ListSetupScreen extends StatefulWidget {
  const ListSetupScreen({super.key});

  @override
  _ListSetupScreenState createState() => _ListSetupScreenState();
}

class _ListSetupScreenState extends State<ListSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _showLengthMinutes = 30;
  int _numberOfSpots = 10;
  int _reservedSpots = 0;
  int _waitListSpots = 0;
  int _bucketSpots = 0;
  String? _locationName;
  String? _showName;
  String? _city;
  String? _state;

  final FirestoreService _firestoreService = FirestoreService();
    final List<String> _bucketNames = [];

  String _getShowLengthText(int minutes) {
    if (minutes == 30) {
      return '30 minutes';
    } else {
      int hours = minutes ~/ 60;
      int remainingMinutes = minutes % 60;
      String hoursText = hours == 1 ? '1 hour' : '$hours hours';
      if (remainingMinutes > 0) {
        return '$hoursText 30 minutes';
      } else {
        return hoursText;
      }
    }
  }

  Future<void> _saveShowDetails() async {
    if (_formKey.currentState?.validate() ?? false) {
      Show show = Show(
        showName: _showName!,
        date: _selectedDate ?? DateTime.now(),
        location: _locationName!,
        city: _city!,
        state: _state!,
        spots: _numberOfSpots,
        reservedSpots: [], //we are creating an empty list here that can be updated later
        spotsList: [], //correct values
        bucketSpots: _bucketSpots > 0,
        waitListSpots: _waitListSpots,
        waitList: [], //we are creating an empty list here that can be updated later
        bucketNames: _bucketNames, //adding bucket names to show object
      );
        await _firestoreService.createShow(show);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
           builder: (context) => const CreatedListsScreen(
             
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CreatedListsScreen()),
          );
        },
      ), 
        title: const Text('Show Setup'),
        backgroundColor: Colors.blue.shade400,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Colors.blue.shade200, Colors.purple.shade100],
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              FadeInDown(
                duration: const Duration(milliseconds: 500),
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Show Name',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (value) {
                    _showName = value;
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a show name';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              FadeInDown(
                duration: const Duration(milliseconds: 600),
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Location Name / Address',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (value) {
                    _locationName = value;
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a location';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              FadeInDown(
                duration: const Duration(milliseconds: 700),
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'City',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (value) {
                    _city = value;
                    
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a city';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              FadeInDown(
                duration: const Duration(milliseconds: 800),
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'State',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (value) {
                    _state = value;
                    
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a state';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              FadeInDown(
                duration: const Duration(milliseconds: 900),
                child: ListTile(
                  title: const Text('Show Date'),
                  subtitle: Text(_selectedDate == null
                      ? 'Select Date'
                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    setState(() {
                      _selectedDate = pickedDate;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              FadeInDown(
                duration: const Duration(milliseconds: 1000),
                child: ListTile(
                  title: const Text('Show Start Time'),
                  subtitle: Text(_selectedTime == null
                      ? 'Select Time'
                      : _selectedTime!.format(context)),
                  onTap: () async {
                    TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime ?? TimeOfDay.now(),
                    );
                    if (pickedTime != null) {
                      setState(() {
                        _selectedTime = pickedTime;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              FadeInDown(
                duration: const Duration(milliseconds: 1100),
                child: ListTile(
                  title: const Text('Show Length'),
                  subtitle: Text(_getShowLengthText(_showLengthMinutes)),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Select Show Length'),
                          content: StatefulBuilder(
                            builder: (BuildContext context, StateSetter setState) {
                              return NumberPicker(
                                value: _showLengthMinutes,
                                minValue: 30,
                                maxValue: 300,
                                step: 30,
                                itemWidth: 50,
                                onChanged: (value) =>
                                    setState(() => _showLengthMinutes = value),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black26),
                                ),
                              );
                            },
                          ),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('OK'),
                              onPressed: () {
                                setState(() {});
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              FadeInDown(
                duration: const Duration(milliseconds: 1200),
                child: SpinBox(
                  value: _numberOfSpots.toDouble(),
                  min: 1,
                  max: 100,
                  step: 1,
                  decoration: const InputDecoration(labelText: 'Number of Spots'),
                  onChanged: (value) =>
                      setState(() => _numberOfSpots = value.toInt()),
                ),
              ),
              const SizedBox(height: 16),
              FadeInDown(
                duration: const Duration(milliseconds: 1200),
                child: const Divider(
                  color: Colors.black,
                  thickness: 2,
                  height: 32,
                ),
              ),
              const SizedBox(height: 16),
              FadeInDown(
                duration: const Duration(milliseconds: 1300),
                child: SpinBox(
                  value: _reservedSpots.toDouble(),
                  min: 0,
                  max: 100,
                  step: 1,
                  decoration: const InputDecoration(labelText: 'Reserved Spots'),
                  onChanged: (value) =>
                      setState(() => _reservedSpots = value.toInt()),
                ),
              ),
              const SizedBox(height: 16),
              FadeInDown(
                duration: const Duration(milliseconds: 1400),
                child: SpinBox(
                  value: _bucketSpots.toDouble(),
                  min: 0,
                  max: 100,
                  step: 1,
                  decoration: const InputDecoration(labelText: 'Bucket Spots'),
                  onChanged: (value) =>
                      setState(() => _bucketSpots = value.toInt()),
                ),
              ),
              const SizedBox(height: 16),
              FadeInDown(
                duration: const Duration(milliseconds: 1500),
                child: SpinBox(
                  value: _waitListSpots.toDouble(),
                  min: 0,
                  max: 100,
                  step: 1,
                  decoration: const InputDecoration(labelText: 'Wait List Spots'),
                  onChanged: (value) =>
                      setState(() => _waitListSpots = value.toInt()),
                ),
              ),
              const SizedBox(height: 24),
              ElasticIn(
                duration: const Duration(milliseconds: 800),
                child: ElevatedButton(
                  onPressed: _saveShowDetails,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue.shade600,
                  ),
                  child: const Text('Save',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}