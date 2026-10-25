import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/models.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  UserType _selectedRole = UserType.worker; // Default to worker

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green[50]!,
              Colors.blue[50]!,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.only(bottom: viewInsets.bottom + 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Section
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Column(
                            children: [
                              // App Logo/Icon
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.local_florist,
                                  size: 40,
                                  color: Colors.green[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Floral Billing System',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Welcome back! Please sign in to continue.',
                                style: TextStyle(
                                  color: Colors.green[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Login Form
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _form,
                            child: Column(
                              children: [
                                // Role-specific welcome message
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _selectedRole == UserType.worker 
                                        ? Colors.blue[50] 
                                        : Colors.orange[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedRole == UserType.worker 
                                          ? Colors.blue[200]! 
                                          : Colors.orange[200]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _selectedRole == UserType.worker 
                                            ? Icons.person 
                                            : Icons.admin_panel_settings,
                                        color: _selectedRole == UserType.worker 
                                            ? Colors.blue[600] 
                                            : Colors.orange[600],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _selectedRole == UserType.worker
                                              ? 'Worker Login - Access billing and inventory'
                                              : 'Admin Login - Full system access',
                                          style: TextStyle(
                                            color: _selectedRole == UserType.worker 
                                                ? Colors.blue[700] 
                                                : Colors.orange[700],
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Role Dropdown
                                DropdownButtonFormField<UserType>(
                                  value: _selectedRole,
                                  decoration: InputDecoration(
                                    labelText: 'Login As',
                                    prefixIcon: const Icon(Icons.person_outline),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: UserType.worker,
                                      child: Text('Worker'),
                                    ),
                                    DropdownMenuItem(
                                      value: UserType.admin,
                                      child: Text('Admin'),
                                    ),
                                  ],
                                  onChanged: (UserType? newValue) {
                                    setState(() {
                                      _selectedRole = newValue!;
                                      _usernameController.text = _selectedRole == UserType.worker ? 'worker' : 'admin';
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                
                                // Username Field
                                TextFormField(
                                  controller: _usernameController,
                                  decoration: InputDecoration(
                                    labelText: 'Username',
                                    prefixIcon: const Icon(Icons.person_outline),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  validator: (v) => v == null || v.isEmpty 
                                      ? 'Please enter username' 
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                
                                // Password Field
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscure,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure ? Icons.visibility : Icons.visibility_off,
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  validator: (v) => v == null || v.isEmpty 
                                      ? 'Please enter password' 
                                      : null,
                                ),
                                
                                // Forgot Password Link (Admin Only)
                                if (_selectedRole == UserType.admin)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => _showForgotPasswordDialog(),
                                        child: Text(
                                          'Forgot Password?',
                                          style: TextStyle(
                                            color: Colors.orange[600],
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                
                                const SizedBox(height: 24),
                                
                                // Login Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _selectedRole == UserType.worker 
                                          ? Colors.blue[600] 
                                          : Colors.orange[600],
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.login, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Sign In as ${_selectedRole == UserType.worker ? 'Worker' : 'Admin'}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final _securityAnswerController = TextEditingController();
    final _newPasswordController = TextEditingController();
    final _confirmPasswordController = TextEditingController();
    bool _obscureNewPassword = true;
    bool _obscureConfirmPassword = true;
    bool _loading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.security,
                color: Colors.orange[600],
                size: 24, // Reduced size
              ),
              const SizedBox(width: 8), // Reduced spacing
              const Text(
                'Security Question',
                style: TextStyle(
                  fontSize: 18, // Reduced font size
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85, // Responsive width
            child: SingleChildScrollView( // Added scroll capability
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Security Question - Made more compact
                  Container(
                    padding: const EdgeInsets.all(12), // Reduced padding
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.pets,
                          color: Colors.orange[600],
                          size: 20, // Reduced size
                        ),
                        const SizedBox(width: 8), // Reduced spacing
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Security Question:',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 12, // Reduced font size
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2), // Reduced spacing
                              Text(
                                'What is the name of your favourite pet?',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 14, // Reduced font size
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16), // Reduced spacing
                  
                  // Security Answer Field - More compact
                  TextFormField(
                    controller: _securityAnswerController,
                    decoration: const InputDecoration(
                      labelText: 'Your Answer',
                      prefixIcon: Icon(Icons.edit_note),
                      border: OutlineInputBorder(),
                      hintText: 'Enter your answer',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12), // Compact padding
                      isDense: true, // Make field more compact
                    ),
                  ),
                  const SizedBox(height: 16), // Reduced spacing
                  
                  // New Password Field - More compact
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setDialogState(() => _obscureNewPassword = !_obscureNewPassword),
                        icon: Icon(
                          _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                      border: const OutlineInputBorder(),
                      hintText: 'Enter new password',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), // Compact padding
                      isDense: true, // Make field more compact
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter new password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12), // Reduced spacing
                  
                  // Confirm Password Field - More compact
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setDialogState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                      border: const OutlineInputBorder(),
                      hintText: 'Confirm new password',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), // Compact padding
                      isDense: true, // Make field more compact
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm new password';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16), // Reduced spacing
                  
                  // Info Text - More compact
                  Container(
                    padding: const EdgeInsets.all(10), // Reduced padding
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[600],
                          size: 18, // Reduced size
                        ),
                        const SizedBox(width: 6), // Reduced spacing
                        Expanded(
                          child: Text(
                            'Answer the security question correctly to reset your admin password.',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12, // Reduced font size
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _loading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: _loading ? null : () async {
                // Validate form
                if (_securityAnswerController.text.isEmpty ||
                    _newPasswordController.text.isEmpty ||
                    _confirmPasswordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                if (_newPasswordController.text != _confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Passwords do not match'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                if (_newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                setDialogState(() => _loading = true);
                
                try {
                  final auth = context.read<AuthService>();
                  await auth.resetAdminPassword(
                    _securityAnswerController.text.trim(),
                    _newPasswordController.text,
                  );
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 8),
                            Text('Admin password reset successfully!'),
                          ],
                        ),
                        backgroundColor: Colors.green[600],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setDialogState(() => _loading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.white),
                            const SizedBox(width: 8),
                            Text('Error: ${e.toString()}'),
                          ],
                        ),
                        backgroundColor: Colors.red[600],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }
                }
              },
              icon: _loading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.lock_reset),
              label: Text(_loading ? 'Resetting...' : 'Reset Password'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_form.currentState!.validate()) return;
    
    setState(() => _loading = true);
    
    final auth = context.read<AuthService>();
    final success = await auth.login(
      _usernameController.text.trim(),
      _passwordController.text,
      userType: _selectedRole, // Pass selected role to login
    );
    
    setState(() => _loading = false);
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Invalid username or password'),
            ],
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
}
