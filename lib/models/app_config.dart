class AppConfig {
  String insertMessage;
  String infoMessage;
  bool konamiCodeEnabled;
  bool coinSlotEnabled;
  bool timeModeEnabled;
  String minutesPerCoin;
  String steamGridDbApiKey;

  AppConfig({
    required this.insertMessage,
    required this.infoMessage,
    required this.konamiCodeEnabled,
    required this.coinSlotEnabled,
    required this.timeModeEnabled,
    required this.minutesPerCoin,
    required this.steamGridDbApiKey,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        insertMessage: json['coinScreen.insertMessage'] as String? ?? '',
        infoMessage: json['coinScreen.infoMessage'] as String? ?? '',
        konamiCodeEnabled: json['coinScreen.konamiCodeEnabled'] == true,
        coinSlotEnabled: json['coinScreen.coinSlotEnabled'] == true,
        timeModeEnabled: json['coinScreen.timeModeEnabled'] == true,
        minutesPerCoin: json['coinScreen.minutesPerCoin']?.toString() ?? '10',
        steamGridDbApiKey: json['steamGridDbApiKey'] as String? ?? '',
      );

  Map<String, dynamic> toUpdateJson() => {
        'coinScreen.insertMessage': insertMessage,
        'coinScreen.infoMessage': infoMessage,
        'coinScreen.konamiCodeEnabled': konamiCodeEnabled,
        'coinScreen.coinSlotEnabled': coinSlotEnabled,
        'coinScreen.timeModeEnabled': timeModeEnabled,
        'coinScreen.minutesPerCoin':
            (int.tryParse(minutesPerCoin) ?? 10).toString(),
        'steamGridDbApiKey': steamGridDbApiKey.isEmpty ? null : steamGridDbApiKey,
      };
}
