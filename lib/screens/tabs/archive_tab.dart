import 'package:flutter/material.dart';
import '../archive/expenses/add_expense_screen.dart';
import '../archive/expenses/expenses_list_screen.dart';
import '../archive/payroll/add_employee_screen.dart';
import '../archive/payroll/daily_wage_screen.dart';
import '../archive/payroll/monthly_salary_screen.dart';
import '../archive/backup_restore_screen.dart';
import '../archive/change_password_screen.dart';
import '../archive/customer_lookup_screen.dart';

class ArchiveTab extends StatelessWidget {
  const ArchiveTab({Key? key}) : super(key: key);

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your business operations efficiently',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Expenses Section
            _buildSection(
              context,
              title: 'Financial Management',
              subtitle: 'Track expenses and manage costs',
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.green,
              items: [
                _MenuItem(
                  icon: Icons.add_business_outlined,
                  title: 'Record Daily Expense',
                  subtitle: 'Add new expense entries',
                  onTap: () => _navigate(context, const AddExpenseScreen()),
                ),
                _MenuItem(
                  icon: Icons.receipt_long_outlined,
                  title: 'View Expense History',
                  subtitle: 'Browse all expense records',
                  onTap: () => _navigate(context, const ExpensesListScreen()),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Payroll Section
            _buildSection(
              context,
              title: 'Human Resources',
              subtitle: 'Employee management and payroll',
              icon: Icons.people_outline,
              color: Colors.blue,
              items: [
                _MenuItem(
                  icon: Icons.person_add_outlined,
                  title: 'Add Employee',
                  subtitle: 'Register new team members',
                  onTap: () => _navigate(context, const AddEmployeeScreen()),
                ),
                _MenuItem(
                  icon: Icons.schedule_outlined,
                  title: 'Pay Daily Wage',
                  subtitle: 'Process daily wage payments',
                  onTap: () => _navigate(context, const DailyWageScreen()),
                ),
                _MenuItem(
                  icon: Icons.payment_outlined,
                  title: 'Pay Monthly Salary',
                  subtitle: 'Process monthly salary payments',
                  onTap: () => _navigate(context, const MonthlySalaryScreen()),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Data Management Section
            _buildSection(
              context,
              title: 'Data Management',
              subtitle: 'Backup and restore your data',
              icon: Icons.backup_outlined,
              color: Colors.orange,
              items: [
                _MenuItem(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Backup & Restore',
                  subtitle: 'Secure your business data',
                  onTap: () => _navigate(context, const BackupRestoreScreen()),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Settings Section
            _buildSection(
              context,
              title: 'Account & Settings',
              subtitle: 'Manage your account preferences',
              icon: Icons.settings_outlined,
              color: Colors.purple,
              items: [
                _MenuItem(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  subtitle: 'Update your security credentials',
                  onTap: () => _navigate(context, const ChangePasswordScreen()),
                ),
                _MenuItem(
                  icon: Icons.search_outlined,
                  title: 'Customer Lookup',
                  subtitle: 'Search and manage customers',
                  onTap: () => _navigate(context, const CustomerLookupScreen()),
                ),
              ],
            ),

            // Bottom padding
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required MaterialColor color, // Changed to MaterialColor
    required List<_MenuItem> items,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withOpacity(0.08),
            offset: const Offset(0, 4),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color.shade700, // Now this will work
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Section Items
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isLast = index == items.length - 1;
                
                return Column(
                  children: [
                    _buildMenuItem(context, item, color),
                    if (!isLast) 
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: theme.colorScheme.outline.withOpacity(0.2),
                        indent: 16,
                        endIndent: 16,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, _MenuItem item, MaterialColor sectionColor) { // Changed to MaterialColor
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: item.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: sectionColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    color: sectionColor.shade700, // Now this will work
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (item.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}
