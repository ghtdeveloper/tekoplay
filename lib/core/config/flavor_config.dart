import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

enum AppFlavor { prod, stage }

class FlavorConfig {
  static late AppFlavor _flavor;
  static FirebaseFirestore? _firestoreInstance;

  static void init(AppFlavor flavor) {
    _flavor = flavor;
    _firestoreInstance = null;
  }

  static AppFlavor get flavor => _flavor;

  static bool get isProd => _flavor == AppFlavor.prod;
  static bool get isStage => _flavor == AppFlavor.stage;

  static String get databaseId => isProd ? 'prod' : 'stage';

  static FirebaseFirestore get firestore {
    _firestoreInstance ??= FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: databaseId,
    );
    return _firestoreInstance!;
  }
}
