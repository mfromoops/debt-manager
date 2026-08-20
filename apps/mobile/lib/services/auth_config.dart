class AuthConfig {
  const AuthConfig._();

  static const workosClientId = String.fromEnvironment('WORKOS_CLIENT_ID');
  static const authBackendBaseUrl =
      String.fromEnvironment('AUTH_BACKEND_BASE_URL');
  static const redirectUri = String.fromEnvironment(
    'WORKOS_REDIRECT_URI',
    defaultValue: 'com.debtfold.app://auth/callback',
  );
  static const provider = String.fromEnvironment('WORKOS_PROVIDER');
  static const organizationId = String.fromEnvironment('WORKOS_ORGANIZATION_ID');
  static const connectionId = String.fromEnvironment('WORKOS_CONNECTION_ID');

  static const authorizationEndpoint =
      'https://api.workos.com/user_management/authorize';

  static bool get hasConnectionSelector =>
      provider.isNotEmpty || organizationId.isNotEmpty || connectionId.isNotEmpty;

  static bool get hasOneConnectionSelector =>
      [provider, organizationId, connectionId].where((value) => value.isNotEmpty).length == 1;

  static bool get isConfigured =>
      workosClientId.isNotEmpty &&
      authBackendBaseUrl.isNotEmpty &&
      hasOneConnectionSelector;

  static Uri authorizationUri(String state) {
    final params = <String, String>{
      'client_id': workosClientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'state': state,
    };
    if (connectionId.isNotEmpty) {
      params['connection'] = connectionId;
    } else if (organizationId.isNotEmpty) {
      params['organization'] = organizationId;
    } else if (provider.isNotEmpty) {
      params['provider'] = provider;
    }
    return Uri.parse(authorizationEndpoint).replace(queryParameters: params);
  }

  static Uri callbackExchangeUri() {
    return Uri.parse(authBackendBaseUrl).resolve('/auth/workos/callback');
  }

  static Uri refreshUri() {
    return Uri.parse(authBackendBaseUrl).resolve('/auth/workos/refresh');
  }
}
