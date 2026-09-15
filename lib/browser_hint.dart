import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_config.dart';

enum BrowserHintAction { inApp, browser }

class BrowserHintChoice {
  const BrowserHintChoice(this.action, {this.remember = false});

  final BrowserHintAction action;
  final bool remember;
}

const String _promptCountKey = 'browser_hint_prompt_count';
const String _rememberedActionKey = 'browser_hint_remembered_action';
const String _actionInApp = 'in_app';
const String _actionBrowser = 'browser';

bool isBrowserHintUrl(WebUri? url) {
  if (url == null) {
    return false;
  }

  final rawUrl = url.toString().trim();
  if (rawUrl.isEmpty) {
    return false;
  }

  final uri = Uri.tryParse(rawUrl);
  return uri?.host.toLowerCase() == AppConfig.browserHintHost;
}

Future<BrowserHintAction> getBrowserHintAction(
  BuildContext context,
  WebUri url,
) async {
  final prefs = await SharedPreferences.getInstance();
  final rememberedAction = prefs.getString(_rememberedActionKey);

  if (rememberedAction == _actionBrowser) {
    return BrowserHintAction.browser;
  }

  if (rememberedAction == _actionInApp) {
    return BrowserHintAction.inApp;
  }

  final promptCount = prefs.getInt(_promptCountKey) ?? 0;
  if (!context.mounted) {
    return BrowserHintAction.inApp;
  }

  final choice = await showBrowserHintDialog(
    context: context,
    url: url,
    canRemember: promptCount > 0,
  );

  await prefs.setInt(_promptCountKey, promptCount + 1);
  if (choice.remember) {
    await prefs.setString(
      _rememberedActionKey,
      choice.action == BrowserHintAction.browser
          ? _actionBrowser
          : _actionInApp,
    );
  }

  return choice.action;
}

Future<BrowserHintChoice> showBrowserHintDialog({
  required BuildContext context,
  required WebUri url,
  required bool canRemember,
}) async {
  var remember = false;
  final choice = await showDialog<BrowserHintChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('打开提示'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '如果出现画面和声音不全，请用手机自带谷歌浏览器打开。',
                ),
                const SizedBox(height: 10),
                Text(
                  url.host,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                if (canRemember) ...<Widget>[
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: remember,
                    onChanged: (value) {
                      setDialogState(() {
                        remember = value ?? false;
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('记住选择'),
                  ),
                ],
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    BrowserHintChoice(
                      BrowserHintAction.browser,
                      remember: remember,
                    ),
                  );
                },
                child: const Text('打开浏览器'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    BrowserHintChoice(
                      BrowserHintAction.inApp,
                      remember: remember,
                    ),
                  );
                },
                child: const Text('直接进入'),
              ),
            ],
          );
        },
      );
    },
  );

  return choice ?? const BrowserHintChoice(BrowserHintAction.inApp);
}

Future<bool> openSystemBrowser(WebUri url) {
  return launchUrl(
    Uri.parse(url.toString()),
    mode: LaunchMode.externalApplication,
  );
}
