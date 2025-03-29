// firebase_options.dart
// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAKEqTR0yFT27UxlneOQNbsKFebqwlj2nY',
    appId: '1:1049808440381:web:ef477a4bce25b9e070ee54',
    messagingSenderId: '1049808440381',
    projectId: 'bookedmic-1cf9d',
    authDomain: 'bookedmic-1cf9d.firebaseapp.com',
    storageBucket: 'bookedmic-1cf9d.firebasestorage.app',
    measurementId: 'G-WTEGV15L7S',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDopcXm8vBWAsK35NupkSD3Hm0153bHFX0',
    appId: '1:1049808440381:android:ae8a666867df29db70ee54',
    messagingSenderId: '1049808440381',
    projectId: 'bookedmic-1cf9d',
    storageBucket: 'bookedmic-1cf9d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCZop-WCP8Ux9Mwb-MLSpRgGIW_avINd44',
    appId: '1:1049808440381:ios:1d6365246c3f31a370ee54',
    messagingSenderId: '1049808440381',
    projectId: 'bookedmic-1cf9d',
    storageBucket: 'bookedmic-1cf9d.firebasestorage.app',
    androidClientId: '1049808440381-fmogcudramlhoaoivphm7ffb6po7k8os.apps.googleusercontent.com',
    iosClientId: '1049808440381-7gebkrrqo9v96chlqob7ukm3oj592fkf.apps.googleusercontent.com',
    iosBundleId: 'com.bookedmic.myapp',
  );

}