import 'package:photo_manager/photo_manager.dart';

class PermissionService {
  Future<bool> requestGalleryPermission() async {
    final result = await PhotoManager.requestPermissionExtend();
    return result.isAuth;
  }

  Future<bool> hasGalleryPermission() async {
    final result = await PhotoManager.requestPermissionExtend();
    return result.isAuth;
  }
}
