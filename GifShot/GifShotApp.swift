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

  init() {
    notifier.requestAuthorization()
  }

  var body: some Scene {
    MenuBarExtra("GifShot", systemImage: appModel.isRecording ? "stop.circle" : "record.circle") {
      MenuContent(saveService: saveService)
        .environmentObject(appModel)
        .padding(8)
    }
  }
}

private struct MenuContent: View {
  @EnvironmentObject var appModel: AppModel
  let saveService: SaveService

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("GifShot")
        .font(.headline)
      Divider()
      // 保存先表示と変更
      VStack(alignment: .leading, spacing: 4) {
        Text("保存先: \(saveService.currentDirectoryPreferred().path)")
          .font(.caption2)
          .lineLimit(2)
          .truncationMode(.middle)
        HStack {
          Button("保存先を変更…") { saveService.changeDirectory() }
          Button("保存フォルダを開く") {
            let dir = saveService.currentDirectoryPreferred()
            Log.app.info("open dir: \(dir.path)")
            NSWorkspace.shared.open(dir)
          }
        }
      }
      Divider()
      // 最大録画時間
      VStack(alignment: .leading, spacing: 4) {
        Text("最大録画時間: \(appModel.maxDurationSeconds)s")
          .font(.caption)
          .foregroundStyle(.secondary)
        HStack(spacing: 6) {
          ForEach([15, 30, 60, 120, 300], id: \.self) { sec in
            Button("\(sec)s") { appModel.updateMaxDuration(seconds: sec) }
              .buttonStyle(.bordered)
          }
        }
      }
      Divider()
      Button(appModel.isRecording ? "録画停止" : "録画開始") {
        appModel.toggleRecording()
      }
      Divider()
      Button("終了") {
        appModel.quitApp()
      }
    }
  }
}
