import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../auth/auth_repository.dart';
import '../order/widgets/order_widgets.dart';

/// Ganti password saat sudah masuk (`POST /password/change`). Sesi tetap
/// berjalan; password baru dipakai saat masuk berikutnya.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  static const _minPasswordLength = 8;

  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  late final _authRepo = context.read<AuthRepository>();

  String? _currentError;
  String? _newError;
  String? _confirmError;
  bool _isLoading = false;

  bool get _canSubmit =>
      _currentController.text.isNotEmpty &&
      _newController.text.isNotEmpty &&
      _confirmController.text.isNotEmpty;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit || _isLoading) return;

    final password = _newController.text;
    if (password.length < _minPasswordLength) {
      setState(
        () => _newError = 'Password minimal $_minPasswordLength karakter',
      );
      return;
    }
    if (password == _currentController.text) {
      setState(() => _newError = 'Password baru sama dengan yang lama');
      return;
    }
    if (_confirmController.text != password) {
      setState(() => _confirmError = 'Password tidak sama');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isLoading = true);

    try {
      await _authRepo.changePassword(
        currentPassword: _currentController.text,
        newPassword: password,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Password berhasil diganti.')),
      );
    } on ApiException catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Kesalahan milik satu kolom ditempel ke kolomnya; sisanya (jaringan,
  /// server) tampil sebagai snackbar.
  void _showError(ApiException e) {
    final fields = e.fieldErrors;
    final current = e.code == 'CURRENT_PASSWORD_INCORRECT'
        ? e.message
        : fields['current_password'];
    final next = fields['new_password'];
    if (current != null || next != null) {
      setState(() {
        _currentError = current;
        _newError = next;
      });
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.light,
        body: SafeArea(
          child: Column(
            children: [
              const ArrowTitleBar('Ganti Password'),
              Expanded(
                child: AutofillGroup(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    children: [
                      AppTextField(
                        label: 'Password saat ini',
                        hint: 'Masukkan password sekarang',
                        controller: _currentController,
                        isPassword: true,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.password],
                        errorText: _currentError,
                        onChanged: (_) => setState(() => _currentError = null),
                      ),
                      const SizedBox(height: 19),
                      AppTextField(
                        label: 'Password baru',
                        hint: 'Minimal $_minPasswordLength karakter',
                        controller: _newController,
                        isPassword: true,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        errorText: _newError,
                        onChanged: (_) => setState(() => _newError = null),
                      ),
                      const SizedBox(height: 19),
                      AppTextField(
                        label: 'Ulangi password baru',
                        hint: 'Ketik ulang password baru',
                        controller: _confirmController,
                        isPassword: true,
                        textInputAction: TextInputAction.done,
                        errorText: _confirmError,
                        onChanged: (_) => setState(() => _confirmError = null),
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 32),
                      PrimaryButton(
                        label: 'Simpan Password',
                        isLoading: _isLoading,
                        onPressed: _canSubmit ? _submit : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
