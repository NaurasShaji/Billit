import 'package:flutter/material.dart';

class WhatsAppIcon extends StatelessWidget {
  const WhatsAppIcon({super.key, this.size = 24});

  final double size;

  static const Color brandGreen = Color(0xFF25D366);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.chat_bubble, size: size, color: brandGreen),
          Padding(
            padding: EdgeInsets.only(bottom: size * 0.06, left: size * 0.02),
            child: Icon(Icons.call, size: size * 0.52, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
