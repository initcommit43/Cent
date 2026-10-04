abstract final class Routes {
  static const home = '/home';
  static const activity = '/activity';
  static const plan = '/plan';
  static const insights = '/insights';

  static const accounts = '/home/accounts';

  static String homeEntry(int id) => '/home/entry/$id';
  static String account(int id) => '/home/accounts/$id';
  static String activityEntry(int id) => '/activity/entry/$id';
  static String budget(int id) => '/plan/budget/$id';
  static String goal(int id) => '/plan/goal/$id';
  static String recurring(int id) => '/plan/recurring/$id';
  static String planEntry(int id) => '/plan/entry/$id';
}
