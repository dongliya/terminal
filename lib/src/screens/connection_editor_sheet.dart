import 'package:flutter/material.dart';
import 'package:terminal/l10n/app_localizations.dart';
import 'package:terminal/src/models/ssh_connection.dart';

class ConnectionEditorSheet extends StatefulWidget {
  const ConnectionEditorSheet({
    super.key,
    this.initialConnection,
  });

  final SshConnection? initialConnection;

  @override
  State<ConnectionEditorSheet> createState() => _ConnectionEditorSheetState();
}

class _ConnectionEditorSheetState extends State<ConnectionEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _privateKeyController;
  late bool _usePassword;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final connection = widget.initialConnection;
    _nameController = TextEditingController(text: connection?.name ?? '');
    _hostController = TextEditingController(text: connection?.host ?? '');
    _portController = TextEditingController(
      text: (connection?.port ?? 22).toString(),
    );
    _usernameController =
        TextEditingController(text: connection?.username ?? '');
    _passwordController =
        TextEditingController(text: connection?.password ?? '');
    _privateKeyController =
        TextEditingController(text: connection?.privateKey ?? '');
    _usePassword = connection == null ? true : connection.usesPassword;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final connection = SshConnection(
      id: widget.initialConnection?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      host: _hostController.text.trim(),
      port: int.parse(_portController.text.trim()),
      username: _usernameController.text.trim(),
      password: _usePassword ? _passwordController.text : null,
      privateKey: _usePassword ? null : _privateKeyController.text.trim(),
    );

    Navigator.of(context).pop(connection);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFF20242A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.initialConnection == null
                              ? l10n.newConnection
                              : l10n.editConnection,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.savedHostsHint,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white60,
                              ),
                        ),
                      ],
                    ),
                  ),
                  _UnderlineField(
                    controller: _nameController,
                    label: l10n.name,
                    hint: l10n.nameHint,
                    icon: Icons.folder_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.enterConnectionName;
                      }
                      return null;
                    },
                  ),
                  _UnderlineField(
                    controller: _hostController,
                    label: l10n.host,
                    hint: l10n.hostHint,
                    icon: Icons.storage_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.enterHost;
                      }
                      return null;
                    },
                  ),
                  _UnderlineField(
                    controller: _portController,
                    label: l10n.port,
                    hint: '22',
                    icon: Icons.tag_rounded,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final port = int.tryParse(value ?? '');
                      if (port == null || port < 1 || port > 65535) {
                        return l10n.enterValidPort;
                      }
                      return null;
                    },
                  ),
                  _UnderlineField(
                    controller: _usernameController,
                    label: l10n.username,
                    icon: Icons.person_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.enterUsername;
                      }
                      return null;
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
                    child: RadioGroup<bool>(
                      groupValue: _usePassword,
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _usePassword = value;
                        });
                      },
                      child: Row(
                        children: <Widget>[
                          _AuthRadio(
                            value: true,
                            selected: _usePassword,
                            label: l10n.password,
                          ),
                          const SizedBox(width: 18),
                          _AuthRadio(
                            value: false,
                            selected: !_usePassword,
                            label: l10n.privateKey,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_usePassword)
                    _UnderlineField(
                      controller: _passwordController,
                      label: l10n.password,
                      icon: Icons.lock_rounded,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        tooltip: l10n.password,
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white54,
                        ),
                      ),
                    )
                  else
                    _UnderlineField(
                      controller: _privateKeyController,
                      label: l10n.privateKey,
                      hint: l10n.privateKeyHint,
                      icon: Icons.key_rounded,
                      minLines: 4,
                      maxLines: 6,
                      alignLabelWithHint: true,
                      validator: (value) {
                        if (!_usePassword &&
                            (value == null || value.trim().isEmpty)) {
                          return l10n.pastePrivateKey;
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          l10n.cancel,
                          style: const TextStyle(
                            color: Color(0xFFC5CBD5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: _submit,
                        child: Text(
                          l10n.save,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnderlineField extends StatelessWidget {
  const _UnderlineField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.validator,
    this.textInputAction,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.minLines,
    this.maxLines = 1,
    this.alignLabelWithHint = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final int? minLines;
  final int maxLines;
  final bool alignLabelWithHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Theme(
        data: theme.copyWith(
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            prefixIconColor: Colors.white60,
            labelStyle: const TextStyle(
              color: Color(0xFFD6DAE1),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            hintStyle: const TextStyle(
              color: Colors.white38,
              fontSize: 15,
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24, width: 1),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.2,
              ),
            ),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24, width: 1),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.redAccent, width: 1),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.redAccent, width: 1.2),
            ),
          ),
        ),
        child: TextFormField(
          controller: controller,
          validator: validator,
          textInputAction: textInputAction,
          keyboardType: keyboardType,
          obscureText: obscureText,
          minLines: minLines,
          maxLines: maxLines,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
          cursorColor: theme.colorScheme.primary,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            alignLabelWithHint: alignLabelWithHint,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: suffixIcon,
          ),
        ),
      ),
    );
  }
}

class _AuthRadio extends StatelessWidget {
  const _AuthRadio({
    required this.value,
    required this.selected,
    required this.label,
  });

  final bool value;
  final bool selected;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        RadioGroup.maybeOf<bool>(context)?.onChanged(value);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Radio<bool>(
            value: value,
            visualDensity: VisualDensity.compact,
            fillColor: WidgetStateProperty.resolveWith<Color>(
              (states) => selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white70,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: selected ? 0.94 : 0.78),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
