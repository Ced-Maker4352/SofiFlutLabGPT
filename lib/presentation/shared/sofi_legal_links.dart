import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A reusable widget to display legal links (Privacy Policy & Terms of Service)
/// Required by Apple Guideline 5.1.1 for all apps with subscriptions.
class SofiLegalLinks extends StatelessWidget {
  final Color textColor;
  final double fontSize;
  final MainAxisAlignment alignment;

  const SofiLegalLinks({
    super.key,
    this.textColor = Colors.white54,
    this.fontSize = 12,
    this.alignment = MainAxisAlignment.center,
  });

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        GestureDetector(
          onTap: () => _launchUrl('https://sofi-saint-app.web.app/privacy'),
          child: Text(
            'Privacy Policy',
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('|', style: TextStyle(color: textColor, fontSize: fontSize)),
        ),
        GestureDetector(
          onTap: () => _launchUrl('https://sofi-saint-app.web.app/terms'),
          child: Text(
            'Terms of Service',
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
