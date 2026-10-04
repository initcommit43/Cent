abstract final class Routes {
  static const home = '/home';
  static const activity = '/activity';
  static const plan = '/plan';
  static const insights = '/insights';

  static const accounts = '/home/accounts';
  static const settings = '/home/settings';
  static const settingsCategories = '/home/settings/categories';
  static const settingsCurrency = '/home/settings/currency';
  static const settingsAppearance = '/home/settings/appearance';
  static const settingsSecurity = '/home/settings/security';
  static const settingsBackup = '/home/settings/backup';
  static const settingsAbout = '/home/settings/about';

  static String homeEntry(int id) => '/home/entry/$id';
  static String account(int id) => '/home/accounts/$id';
  static String activityEntry(int id) => '/activity/entry/$id';
  static String budget(int id) => '/plan/budget/$id';
  static String goal(int id) => '/plan/goal/$id';
  static String recurring(int id) => '/plan/recurring/$id';
  static String planEntry(int id) => '/plan/entry/$id';
  static String insightsCategory(int id) => '/insights/category/$id';
  static String insightsEntry(int id) => '/insights/entry/$id';
}
