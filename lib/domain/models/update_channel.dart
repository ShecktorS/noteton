/// Canale usato dal sistema di aggiornamenti in-app.
///
/// - [stable]: considera solo release ufficiali GitHub.
/// - [beta]: considera anche pre-release (beta/alpha/rc), oltre alle stable.
enum UpdateChannel {
  stable,
  beta;

  bool get includesPrereleases => this == UpdateChannel.beta;

  static UpdateChannel fromStorage(String? value) {
    return switch (value) {
      'beta' => UpdateChannel.beta,
      'stable' => UpdateChannel.stable,
      _ => UpdateChannel.stable,
    };
  }
}
