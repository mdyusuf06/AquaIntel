import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A black pill CTA button (or outlined variant).
/// Usage:
///   PillButton(label: 'Get started', onPressed: () {}, fullWidth: true)
///   PillButton(label: 'Cancel', outlined: true, onPressed: () {})
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool fullWidth;
  final IconData? leadingIcon;
  final double height;

  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.outlined = false,
    this.fullWidth = false,
    this.leadingIcon,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = leadingIcon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(leadingIcon, size: 18),
              const SizedBox(width: 8),
              Text(label),
            ],
          )
        : Text(label);

    Widget btn = outlined
        ? OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0D0D0D),
              side: const BorderSide(color: Color(0xFFEBEBEB), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 15),
              minimumSize: Size(0, height),
            ),
            child: child,
          )
        : SizedBox(
            height: height,
            child: ElevatedButton(
              onPressed: onPressed,
              child: child,
            ),
          );

    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
