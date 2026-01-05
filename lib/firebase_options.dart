import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration options
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
        return macos;
      case TargetPlatform.windows:
        return windows;
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
    apiKey: 'AIzaSyAMJx5jnVLCnUmDwCfGiq_usRY6bz1wwPU',
    appId: '1:149451670785:web:6e0cc9312108f5f2220700',
    messagingSenderId: '149451670785',
    projectId: 'bruteforcecamera',
    authDomain: 'bruteforcecamera.firebaseapp.com',
    databaseURL: 'https://bruteforcecamera-default-rtdb.firebaseio.com',
    storageBucket: 'bruteforcecamera.appspot.com',
    measurementId: 'G-H25RDTVEPW',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCVGUQtHDMsBnSVEyBMUE_NZgZB6zhE6Fw',
    appId: '1:149451670785:android:d9c15b707c295c07220700',
    messagingSenderId: '149451670785',
    projectId: 'bruteforcecamera',
    databaseURL: 'https://bruteforcecamera-default-rtdb.firebaseio.com',
    storageBucket: 'bruteforcecamera.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBI9aNGO5-3CQr8ykMX3WIRKmMPPyLhuP4',
    appId: '1:149451670785:ios:96df8dcea4e4d160220700',
    messagingSenderId: '149451670785',
    projectId: 'bruteforcecamera',
    databaseURL: 'https://bruteforcecamera-default-rtdb.firebaseio.com',
    storageBucket: 'bruteforcecamera.appspot.com',
    iosClientId: '149451670785-on3nin09qmfh7ojlgsrsctcjg60p984i.apps.googleusercontent.com',
    iosBundleId: 'com.example.lendly',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBI9aNGO5-3CQr8ykMX3WIRKmMPPyLhuP4',
    appId: '1:149451670785:ios:96df8dcea4e4d160220700',
    messagingSenderId: '149451670785',
    projectId: 'bruteforcecamera',
    databaseURL: 'https://bruteforcecamera-default-rtdb.firebaseio.com',
    storageBucket: 'bruteforcecamera.appspot.com',
    iosClientId: '149451670785-on3nin09qmfh7ojlgsrsctcjg60p984i.apps.googleusercontent.com',
    iosBundleId: 'com.example.lendly',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAMJx5jnVLCnUmDwCfGiq_usRY6bz1wwPU',
    appId: '1:149451670785:web:6e0cc9312108f5f2220700',
    messagingSenderId: '149451670785',
    projectId: 'bruteforcecamera',
    authDomain: 'bruteforcecamera.firebaseapp.com',
    databaseURL: 'https://bruteforcecamera-default-rtdb.firebaseio.com',
    storageBucket: 'bruteforcecamera.appspot.com',
    measurementId: 'G-H25RDTVEPW',
  );

}

