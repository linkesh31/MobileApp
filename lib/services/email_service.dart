import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

class EmailService {
  final String username = 'linkeshjpr.25@gmail.com';
  final String password = 'mkmwofeutemcvdsn';

  Future<void> sendOtpEmail({
    required String recipientEmail,
    required String otp,
  }) async {
    final smtpServer = gmail(username, password);

    final message = Message()
      ..from = Address(username, 'StashTrack OTP')
      ..recipients.add(recipientEmail)
      ..subject = 'Your OTP Verification Code'
      ..text = 'Your OTP code is: $otp\n\nThis code will expire in 5 minutes.';

    try {
      await send(message, smtpServer);
    } catch (e) {
      print('Email send error: $e');
      rethrow;
    }
  }
}
