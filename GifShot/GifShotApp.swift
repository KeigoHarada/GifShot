//
//  GifShotApp.swift
//  GifShot
//
//  Created by 原田啓吾 on 2025/09/22.
//

import SwiftUI

@main
struct GifShotApp: App {
    @StateObject private var appModel = AppModel()
    private let saveService = SaveService()
    private let notifier = NotifierService()
    @State private var showHotkeySheet = false

    init() {
        notifier.requestAuthorization()
    }

    var body: some Scene {
        MenuBarExtra("GifShot", systemImage: appModel.isRecording ? "stop.circle" : "record.circle") {
            VStack(alignment: .leading, spacing: 8) {
                Text("GifShot")
                    .font(.headline)
                Divider()
                Button(appModel.isRecording ? "録画停止" : "録画開始") {
                    appModel.toggleRecording()
                }
                Button("ショートカットを変更…") { showHotkeySheet = true }
                Button("保存フォルダを開く") {
                    if let dir = try? saveService.ensureDirectory() {
                        Log.app.info("open dir: \(dir.path)")
                        NSWorkspace.shared.open(dir)
                    } else {
                        Log.app.error("open dir failed")
                    }
                }
                Divider()
                Button("終了") {
                    appModel.quitApp()
                }
            }
            .padding(8)
            .sheet(isPresented: $showHotkeySheet) {
                HotkeyCaptureView { keyCode, mods in
                    appModel.updateHotkey(keyCode: keyCode, modifiers: mods)
                }
            }
        }
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
    }
}
