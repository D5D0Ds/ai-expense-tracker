import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Provides platform permission operations.
final permissionGatewayProvider = Provider<PermissionGateway>(
  (ref) => const PermissionHandlerGateway(),
);

/// App permissions used by feature UI.
enum AppPermission {
  /// SMS inbox access.
  sms,

  /// Notification delivery access.
  notification,
}

/// Permission state understood by the app UI.
enum AppPermissionStatus {
  /// Permission has been granted.
  granted,

  /// Permission has been permanently denied or blocked by the platform.
  blocked,

  /// Permission can still be requested.
  requestable,
}

/// Contract for platform permission operations.
abstract interface class PermissionGateway {
  /// Reads the current status for [permission].
  Future<AppPermissionStatus> status(AppPermission permission);

  /// Requests [permission] from the platform.
  Future<AppPermissionStatus> request(AppPermission permission);

  /// Opens the platform app settings page.
  Future<bool> openSettings();
}

/// permission_handler-backed implementation.
final class PermissionHandlerGateway implements PermissionGateway {
  /// Creates a gateway.
  const PermissionHandlerGateway();

  @override
  Future<AppPermissionStatus> status(AppPermission permission) async {
    return _mapStatus(await permission.toPlatform.status);
  }

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async {
    return _mapStatus(await permission.toPlatform.request());
  }

  @override
  Future<bool> openSettings() => openAppSettings();
}

extension on AppPermission {
  Permission get toPlatform {
    return switch (this) {
      AppPermission.sms => Permission.sms,
      AppPermission.notification => Permission.notification,
    };
  }
}

AppPermissionStatus _mapStatus(PermissionStatus status) {
  if (status.isGranted) return AppPermissionStatus.granted;
  if (status.isPermanentlyDenied || status.isRestricted) return AppPermissionStatus.blocked;
  return AppPermissionStatus.requestable;
}
