import 'package:flutter/material.dart';
import 'package:myapp/host_screens/created_lists_screen.dart';
import 'package:myapp/providers/firestore_provider.dart';
import 'package:myapp/providers/bmic_app_state.dart';

import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Make sure to add this


Future<void> main() async {
        WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      runApp(MyApp());
    }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => FirestoreProvider()),
        ChangeNotifierProvider(create: (context) => BmicAppState()),
      ],
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        // home: PerformerListScreen(),
        // home: RoleSelectionScreen(),
         home: CreatedListsScreen(),
        //home: RegistrationScreen()
      ),
    );
  }
}


