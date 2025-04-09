// providers/bmic_app_state.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BmicAppState extends ChangeNotifier {
  String? _role;
  String _performerId = '';

  String? get role => _role;
  String get performerId => _performerId;

  BmicAppState() {
    _loadRole();
  }

  void setRole(String role) async {
    _role = role;
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('role', role);
  }

  void setPerformerId(String performerId) {
    _performerId = performerId;
    notifyListeners();
  }

  void _loadRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _role = prefs.getString('role');
    notifyListeners();
  }

  void listenToPerformerUpdates(String showId, BuildContext context) {
    FirebaseFirestore.instance.collection('shows').doc(showId).collection('signups').snapshots().listen((snapshot) {
      int performerIndex = snapshot.docs.indexWhere((doc) => doc.id == _performerId);
      if (performerIndex != -1) {
        int performersAhead = performerIndex;
        // Show snackbar notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$performersAhead performers ahead of you')),
        );
      }
    });
  }
}