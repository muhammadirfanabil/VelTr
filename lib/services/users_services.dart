import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/users_info.dart';

class UserService {
  final CollectionReference usersRef = FirebaseFirestore.instance.collection(
    'users_information',
  );

  Future<void> addUser(UserInformation user) {
    return usersRef.add(user.toMap());
  }

  Stream<List<UserInformation>> getUsers() {
    return usersRef.snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map(
                (doc) => UserInformation.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
    );
  }

  Future<void> updateUser(UserInformation user) {
    return usersRef.doc(user.id).update(user.toMap());
  }

  Future<void> deleteUser(String id) {
    return usersRef.doc(id).delete();
  }
}
