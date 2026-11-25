import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';

/// Rounded password input on a `surface` fill, with a show/hide toggle.
class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.visible,
    required this.onToggleVisible,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hint;
  final bool visible;
  final VoidCallback onToggleVisible;
  final VoidCallback? onChanged;
  final VoidCallback? onSubmitted;
  final bool autofocus;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return TextField(
      controller: controller,
      obscureText: !visible,
      autofocus: autofocus,
      textInputAction: textInputAction,
      onChanged: (_) => onChanged?.call(),
      onSubmitted: (_) => onSubmitted?.call(),
      style: textTheme.bodyLarge?.copyWith(color: palette.onCanvas),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: palette.onCanvasMuted,
        ),
        suffixIcon: IconButton(
          tooltip: visible ? 'Hide password' : 'Show password',
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: palette.onCanvasMuted,
          ),
          onPressed: onToggleVisible,
        ),
      ),
    );
  }
}

/// Shared frame for the password dialogs: title, description, content, an
/// optional error line, and the action buttons.
class _DialogFrame extends StatelessWidget {
  const _DialogFrame({
    required this.title,
    required this.description,
    required this.fields,
    required this.errorMessage,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    this.busy = false,
  });

  final String title;
  final String description;
  final List<Widget> fields;
  final String? errorMessage;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: textTheme.displaySmall),
            const SizedBox(height: AppSpacing.sm),
            Text(description, style: textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.xl),
            for (var i = 0; i < fields.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              fields[i],
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: palette.error,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: textTheme.bodySmall?.copyWith(
                        color: palette.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppPillButton(
              label: confirmLabel,
              onPressed: busy ? null : onConfirm,
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: busy ? null : onCancel,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for creating a new parental control password.
class CreatePasswordDialog extends StatefulWidget {
  final Function(String password) onConfirm;

  const CreatePasswordDialog({super.key, required this.onConfirm});

  @override
  State<CreatePasswordDialog> createState() => _CreatePasswordDialogState();
}

class _CreatePasswordDialogState extends State<CreatePasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  void _handleSetup() {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty) {
      setState(() => _errorMessage = 'Password cannot be empty');
      return;
    }
    if (password.length < 4) {
      setState(() => _errorMessage = 'Use at least 4 characters');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    Navigator.of(context).pop();
    widget.onConfirm(password);
  }

  @override
  Widget build(BuildContext context) {
    return _DialogFrame(
      title: 'New password',
      description:
          'Choose a password for parental mode. You will need it to '
          'turn parental mode off or change what is blocked.',
      errorMessage: _errorMessage,
      confirmLabel: 'Set password',
      onConfirm: _handleSetup,
      onCancel: () => Navigator.of(context).pop(),
      fields: [
        _PasswordField(
          controller: _passwordController,
          hint: 'Password',
          autofocus: true,
          textInputAction: TextInputAction.next,
          visible: _passwordVisible,
          onToggleVisible: () =>
              setState(() => _passwordVisible = !_passwordVisible),
          onChanged: _clearError,
        ),
        _PasswordField(
          controller: _confirmPasswordController,
          hint: 'Confirm password',
          textInputAction: TextInputAction.done,
          visible: _confirmPasswordVisible,
          onToggleVisible: () => setState(
            () => _confirmPasswordVisible = !_confirmPasswordVisible,
          ),
          onChanged: _clearError,
          onSubmitted: _handleSetup,
        ),
      ],
    );
  }
}

/// Dialog asking for the parental control password. Pops `true` when
/// [onVerify] accepts it.
class VerifyPasswordDialog extends StatefulWidget {
  final String title;
  final String description;
  final Future<bool> Function(String password) onVerify;

  const VerifyPasswordDialog({
    super.key,
    required this.title,
    required this.description,
    required this.onVerify,
  });

  @override
  State<VerifyPasswordDialog> createState() => _VerifyPasswordDialogState();
}

class _VerifyPasswordDialogState extends State<VerifyPasswordDialog> {
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _busy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final password = _passwordController.text.trim();

    if (password.isEmpty) {
      setState(() => _errorMessage = 'Enter your password');
      return;
    }

    setState(() {
      _errorMessage = null;
      _busy = true;
    });

    final isCorrect = await widget.onVerify(password);
    if (!mounted) return;

    if (isCorrect) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _errorMessage = 'Incorrect password';
        _passwordController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DialogFrame(
      title: widget.title,
      description: widget.description,
      errorMessage: _errorMessage,
      confirmLabel: _busy ? 'Checking...' : 'Continue',
      busy: _busy,
      onConfirm: _handleVerify,
      onCancel: () => Navigator.of(context).pop(),
      fields: [
        _PasswordField(
          controller: _passwordController,
          hint: 'Password',
          autofocus: true,
          textInputAction: TextInputAction.done,
          visible: _passwordVisible,
          onToggleVisible: () =>
              setState(() => _passwordVisible = !_passwordVisible),
          onChanged: () {
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
          onSubmitted: _handleVerify,
        ),
      ],
    );
  }
}
