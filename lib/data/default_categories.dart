import '../core/database/app_database.dart';

class CategorySeed {
  const CategorySeed(this.name, this.icon, this.tint, this.kind);

  final String name;

  /// Lucide icon name.
  final String icon;
  final String tint;
  final CategoryKind kind;
}

const defaultCategories = [
  CategorySeed('Groceries', 'shopping-cart', 'copper', CategoryKind.expense),
  CategorySeed('Eating out', 'utensils', 'brass', CategoryKind.expense),
  CategorySeed('Coffee', 'coffee', 'brass', CategoryKind.expense),
  CategorySeed('Transport', 'bus', 'neutral', CategoryKind.expense),
  CategorySeed('Shopping', 'shirt', 'copper', CategoryKind.expense),
  CategorySeed('Home', 'house', 'patina', CategoryKind.expense),
  CategorySeed('Subscriptions', 'smartphone', 'blush', CategoryKind.expense),
  CategorySeed('Health', 'heart-pulse', 'patina', CategoryKind.expense),
  CategorySeed('Leisure', 'film', 'blush', CategoryKind.expense),
  CategorySeed('Travel', 'plane', 'patina', CategoryKind.expense),
  CategorySeed('Education', 'graduation-cap', 'brass', CategoryKind.expense),
  CategorySeed('Fitness', 'dumbbell', 'copper', CategoryKind.expense),
  CategorySeed('Gifts', 'gift', 'blush', CategoryKind.expense),
  CategorySeed('Utilities', 'zap', 'brass', CategoryKind.expense),
  CategorySeed('Other', 'ellipsis', 'neutral', CategoryKind.expense),
  CategorySeed('Salary', 'briefcase', 'patina', CategoryKind.income),
  CategorySeed('Gifts received', 'gift', 'brass', CategoryKind.income),
  CategorySeed('Interest', 'piggy-bank', 'patina', CategoryKind.income),
  CategorySeed('Other income', 'ellipsis', 'neutral', CategoryKind.income),
];
