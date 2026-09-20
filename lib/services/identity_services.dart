import '../models/player_progress.dart';

abstract interface class AuthenticationService {
  String get localPlayerId;
  bool get isGuest;
}

class GuestAuthenticationService implements AuthenticationService {
  const GuestAuthenticationService([this.localPlayerId = 'local_guest']);
  @override
  final String localPlayerId;
  @override
  bool get isGuest => true;
}

abstract interface class CloudProgressService {
  Future<PlayerProgress?> download(String playerId);
  Future<void> upload(String playerId, PlayerProgress progress);
  Future<PlayerProgress> merge(PlayerProgress local, PlayerProgress cloud);
}
