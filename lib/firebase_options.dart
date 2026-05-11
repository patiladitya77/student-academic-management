// File generated manually based on Firebase project configuration.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('No iOS configuration provided.');
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAK4SuQEn0W0Ongyz9bFKpWZkyUjTICKL0',
    authDomain: 'student-academic-management.firebaseapp.com',
    projectId: 'student-academic-management',
    storageBucket: 'student-academic-management.firebasestorage.app',
    messagingSenderId: '272496741788',
    appId: '1:272496741788:web:b53811400b66a30b424c59',
    databaseURL: 'https://student-academic-management-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDSdrDjR6tgb8Or6Bq1k-uwDK_13YLij2Y',
    appId: '1:272496741788:android:b3392d33fbe0b8d8424c59',
    messagingSenderId: '272496741788',
    projectId: 'student-academic-management',
    storageBucket: 'student-academic-management.firebasestorage.app',
  );
}
