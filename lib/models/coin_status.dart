class CoinStatus {
  final int credits;
  final int remainingSeconds;
  final bool timeMode;
  final bool hardwareConnected;
  final bool freePlay;
  final bool coinSlotEnabled;

  CoinStatus({
    required this.credits,
    required this.remainingSeconds,
    required this.timeMode,
    required this.hardwareConnected,
    required this.freePlay,
    required this.coinSlotEnabled,
  });

  factory CoinStatus.fromJson(Map<String, dynamic> json) => CoinStatus(
        credits: (json['credits'] as num?)?.toInt() ?? 0,
        remainingSeconds: (json['remainingSeconds'] as num?)?.toInt() ?? 0,
        timeMode: json['timeMode'] == true,
        hardwareConnected: json['hardwareConnected'] == true,
        freePlay: json['freePlay'] == true,
        coinSlotEnabled: json['coinSlotEnabled'] == true,
      );

  String get formattedTime {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
