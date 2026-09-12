import 'app_user.dart';

abstract class UserRepository {
  Future<AppUser?> getUser(String uid);

  Stream<AppUser?> watchUser(String uid);
}
