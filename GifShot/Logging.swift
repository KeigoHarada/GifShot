import os

enum Log {
  static let app = Logger(subsystem: "com.gmail.hkddna5.GifShot", category: "App")
  static let hotkey = Logger(subsystem: "com.gmail.hkddna5.GifShot", category: "Hotkey")
  static let overlay = Logger(subsystem: "com.gmail.hkddna5.GifShot", category: "Overlay")
  static let recorder = Logger(subsystem: "com.gmail.hkddna5.GifShot", category: "Recorder")
}
