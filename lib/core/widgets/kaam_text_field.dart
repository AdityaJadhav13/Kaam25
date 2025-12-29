import 'package:flutter/material.dart';

class KaamTextField extends StatelessWidget {
  const KaamTextField({
    required this.controller,
    required this.hintText,
    this.labelText,
    this.leadingIcon,
    this.obscureText = false,
    this.keyboardType,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final String? labelText;
  final IconData? leadingIcon;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: leadingIcon == null ? null : Icon(leadingIcon, size: 20),
      ),
    );

    if (labelText == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText!,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}
