import 'package:flutter/material.dart';

import '../archive/archive_category_screen.dart';
import '../archive/expenses/add_expense_screen.dart';
import '../archive/expenses/expenses_list_screen.dart';
import '../archive/payroll/add_employee_screen.dart';
import '../archive/payroll/daily_wage_screen.dart';
import '../archive/payroll/monthly_salary_screen.dart';
import '../archive/backup_restore_screen.dart';
import '../archive/change_password_screen.dart';
import '../security_question_settings_screen.dart';
import '../archive/customer_lookup_screen.dart';
import '../archive/bulk_product_import_screen.dart';
import '../archive/gst_exports_screen.dart';

class ArchiveTab extends StatelessWidget {
  const ArchiveTab({super.key});

  List<_ArchiveCategory> _categories() => [
        _ArchiveCategory(
          title: 'Financial Management',
          subtitle: 'Expenses and cost tracking',
          description:
              'Record and review expenses.',
          icon: Icons.account_balance_wallet_outlined,
          color: Colors.green,
          items: [
            ArchiveCategoryItem(
              icon: Icons.add_card_outlined,
              title: 'Record Daily Expense',
              subtitle: 'Add a new expense entry',
              builder: (_) => const AddExpenseScreen(),
            ),
            ArchiveCategoryItem(
              icon: Icons.receipt_long_outlined,
              title: 'View Expense History',
              subtitle: 'Browse recorded expenses',
              builder: (_) => const ExpensesListScreen(),
            ),
          ],
        ),
        _ArchiveCategory(
          title: 'Human Resources',
          subtitle: 'Employees and payroll',
          description: 'Employees and payroll.',
          icon: Icons.groups_outlined,
          color: Colors.blue,
          items: [
            ArchiveCategoryItem(
              icon: Icons.person_add_alt_1_outlined,
              title: 'Add Employee',
              subtitle: 'Register a team member',
              builder: (_) => const AddEmployeeScreen(),
            ),
            ArchiveCategoryItem(
              icon: Icons.today_outlined,
              title: 'Pay Daily Wage',
              subtitle: 'Process daily wage payments',
              builder: (_) => const DailyWageScreen(),
            ),
            ArchiveCategoryItem(
              icon: Icons.payments_outlined,
              title: 'Pay Monthly Salary',
              subtitle: 'Process monthly salary payments',
              builder: (_) => const MonthlySalaryScreen(),
            ),
          ],
        ),
        _ArchiveCategory(
          title: 'Product Management',
          subtitle: 'Bulk product import',
          description:
              'Import products from Excel.',
          icon: Icons.inventory_2_outlined,
          color: Colors.teal,
          items: [
            ArchiveCategoryItem(
              icon: Icons.table_view_outlined,
              title: 'Bulk Add Products (Excel)',
              subtitle: 'Import products, prices, stock, barcodes and GST',
              builder: (_) => const BulkProductImportScreen(),
            ),
          ],
        ),
        _ArchiveCategory(
          title: 'Reports & Statements',
          subtitle: 'Sales statements and GST exports',
          description:
              'Export sales, GST and expense reports.',
          icon: Icons.assessment_outlined,
          color: Colors.deepOrange,
          items: [
            ArchiveCategoryItem(
              icon: Icons.file_download_outlined,
              title: 'Reports & Statements',
              subtitle:
                  'Sales statements, GST sales, item and expense registers',
              builder: (_) => const GstExportsScreen(),
            ),
          ],
        ),
        _ArchiveCategory(
          title: 'Data Management',
          subtitle: 'Backup and restore',
          description: 'Back up or restore data.',
          icon: Icons.cloud_sync_outlined,
          color: Colors.orange,
          items: [
            ArchiveCategoryItem(
              icon: Icons.backup_outlined,
              title: 'Backup & Restore',
              subtitle: 'Manage your Google Drive backups',
              builder: (_) => const BackupRestoreScreen(),
            ),
          ],
        ),
        _ArchiveCategory(
          title: 'Account & Settings',
          subtitle: 'Account tools and customer search',
          description: 'Security and customer search.',
          icon: Icons.settings_outlined,
          color: Colors.deepPurple,
          items: [
            ArchiveCategoryItem(
              icon: Icons.security_outlined,
              title: 'Security Question',
              subtitle: 'Update recovery question.',
              builder: (_) => const SecurityQuestionSettingsScreen(),
            ),
            ArchiveCategoryItem(
              icon: Icons.lock_outline,
              title: 'Change Password',
              subtitle: 'Update your account password',
              builder: (_) => const ChangePasswordScreen(),
            ),
            ArchiveCategoryItem(
              icon: Icons.person_search_outlined,
              title: 'Customer Lookup',
              subtitle: 'Search customer information',
              builder: (_) => const CustomerLookupScreen(),
            ),
          ],
        ),
      ];

  void _openCategory(BuildContext context, _ArchiveCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArchiveCategoryScreen(
          title: category.title,
          description: category.description,
          icon: category.icon,
          color: category.color,
          items: category.items,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categories = _categories();

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 560
                    ? 2
                    : 1;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Archive',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Business tools and account management',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'CATEGORIES',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: categories.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 116,
                    ),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return _CategoryCard(
                        category: category,
                        onTap: () => _openCategory(context, category),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ArchiveCategory {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final MaterialColor color;
  final List<ArchiveCategoryItem> items;

  const _ArchiveCategory({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.items,
  });
}

class _CategoryCard extends StatelessWidget {
  final _ArchiveCategory category;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  category.icon,
                  color: category.color.shade800,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.60),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurface.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
