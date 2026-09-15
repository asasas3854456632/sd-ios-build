class AppConfig {
  const AppConfig._();

  static const String appName = '盛达';

  // gitee 备用json
  static const String domainUpdateJsonUrl =
      'https://sd1249.com/apijson/domains.json';

  // API 备用json列表
  static const List<String> apiDomainUrls = <String>[
    'https://sjjjsss.oss-cn-hongkong.aliyuncs.com/domains.json',
    'https://sd1249.com/apijson/domains.json',
  ];

  // 用这个路径判断 WebView 域名是否可用，默认请求 https://domain/favicon.ico。
  static const String domainIconPath = '/favicon.png';

  static const String browserHintHost = 'gci.hn55555.com';
}
