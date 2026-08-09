/// Configuration for the PharmaFinder administrator portal.
class AdminConfig {
  /// Secret code required to create the very FIRST administrator account.
  ///
  /// This is a bootstrap guard only. After you have created your admin
  /// account you should:
  ///   1. Change this value, AND
  ///   2. Update the matching `validBootstrapKey` value in `firestore.rules`
  ///      (or remove the bootstrap rule entirely) and redeploy the rules.
  static const String adminSetupCode = 'PharmaAdmin#2026';

  /// Secret URL route (hash) that opens the Administrator Portal.
  ///
  /// There is no button or link anywhere in the app that points here; only
  /// people who know this path can reach the admin portal. Change it to
  /// anything you like, e.g.:
  ///   https://pharma-finder-6d99d.web.app/#/admin-console
  static const String adminRoutePath = '/admin-console';
}
