import 'package:flutter/material.dart';

enum DepositLinkAction { inApp, browser }

Future<DepositLinkAction> showDepositLinkPrompt(BuildContext context) async {
  final action = await showDialog<DepositLinkAction>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('打开提示'),
        content: const Text('如果出现无法跳转微信/支付宝请用浏览器打开'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(DepositLinkAction.browser);
            },
            child: const Text('去浏览器'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(DepositLinkAction.inApp);
            },
            child: const Text('直接进入'),
          ),
        ],
      );
    },
  );

  return action ?? DepositLinkAction.inApp;
}
