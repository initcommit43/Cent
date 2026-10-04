abstract final class Routes {
  static const home = '/home';
  static const activity = '/activity';
  static const activitySearch = '/activity/search';
  static const plan = '/plan';
  static const insights = '/insights';

  static String homeEntry(int id) => '/home/entry/$id';
  static String activityEntry(int id) => '/activity/entry/$id';
}
