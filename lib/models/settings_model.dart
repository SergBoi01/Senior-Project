// ------------------------------------------------ //
//  Classes: Settings
// ------------------------------------------------ //

class Settings {
  double timeThreshold;
  double spatialThreshold;
  double minSymbolSize;
  double penWidth;

  Settings({
    this.timeThreshold = 1000,
    this.spatialThreshold = 50,
    this.minSymbolSize = 100,
    this.penWidth = 10,
  });

  Map<String, dynamic> toJson() => {
    'timeThreshold': timeThreshold,
    'spatialThreshold': spatialThreshold,
    'minSymbolSize': minSymbolSize,
    'penWidth': penWidth,
  };

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      timeThreshold: json['timeThreshold'] ?? 1000,
      spatialThreshold: json['spatialThreshold'] ?? 50,
      minSymbolSize: json['minSymbolSize'] ?? 100,
      penWidth: json['penWidth'] ?? 10,
    );
  }
}
