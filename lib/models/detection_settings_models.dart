class DetectionSettings {
  double timeThreshold;
  double spatialThreshold;
  double minSymbolSize;

  DetectionSettings({
    this.timeThreshold = 1000,
    this.spatialThreshold = 50,
    this.minSymbolSize = 100,
  });

  Map<String, dynamic> toJson() => {
    'timeThreshold': timeThreshold,
    'spatialThreshold': spatialThreshold,
    'minSymbolSize': minSymbolSize,
  };

  factory DetectionSettings.fromJson(Map<String, dynamic> json) {
    return DetectionSettings(
      timeThreshold: json['timeThreshold'] ?? 1000,
      spatialThreshold: json['spatialThreshold'] ?? 50,
      minSymbolSize: json['minSymbolSize'] ?? 100,
    );
  }
}
