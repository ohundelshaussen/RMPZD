import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/phone_number.dart';

class ContactPhoneAction extends StatelessWidget {
  final String phone;

  const ContactPhoneAction({required this.phone, super.key});

  Future<void> _call(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: PhoneNumber.toDialString(phone));
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      launched = false;
    } on MissingPluginException {
      launched = false;
    }

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo iniciar la llamada.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Teléfono de contacto'),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            phone,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton.icon(
          onPressed: () => _call(context),
          icon: const Icon(Icons.call_outlined, size: 18),
          label: const Text('Llamar'),
        ),
      ],
    );
  }
}
