import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../config/theme.dart';

class LoadingIndicator extends StatelessWidget {
  final String? message;
  final bool useLottie;
  
  const LoadingIndicator({
    Key? key,
    this.message,
    this.useLottie = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (useLottie)
            SizedBox(
              height: 150,
              width: 150,
              child: Lottie.asset(
                'assets/animations/loading.json',
                animate: true,
                repeat: true,
              ),
            )
          else
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}