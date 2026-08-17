class SyncConfig {
  const SyncConfig._();

  static const syncBackendBaseUrl =
      String.fromEnvironment('SYNC_BACKEND_BASE_URL');

  static bool get isConfigured => syncBackendBaseUrl.isNotEmpty;

  static Uri stateUri() {
    return Uri.parse(syncBackendBaseUrl).resolve('/sync/state');
  }
}
