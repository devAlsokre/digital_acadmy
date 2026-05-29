class ActivationApiConfig {
  const ActivationApiConfig._();

  static const String activationUrl = String.fromEnvironment(
    'ACTIVATION_API_URL',
    defaultValue: '',
  );

  static bool get isConfigured => activationUrl.trim().isNotEmpty;
}
