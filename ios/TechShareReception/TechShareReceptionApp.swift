import SwiftUI
import CoreNFC

@main
struct TechShareReceptionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// ログデータ構造
struct ScanLog: Identifiable, Codable {
    var id = UUID()
    let timestamp: String
    let room: String
    let cardId: String
}

struct ContentView: View {
    @State private var selectedVenue = "シマブン 13F (総合受付)"
    @State private var selectedWsRoom = "神鋼ビル 6階 (WS 小部屋1: BI実践入門)"
    @State private var scanLogs: [ScanLog] = []
    @State private var lastScannedId: String = ""
    @State private var lastScannedTime: String = ""
    @State private var statusMessage: String = "「社員証をスキャン」を押してください"
    @State private var isShowingShareSheet = false
    @State private var shareURL: URL?

    @StateObject private var nfcReader = NFCReader()

    let venues = [
        "シマブン 13F (総合受付)",
        "シマブン 13F (Track 1: AI・新技術)",
        "シマブン 11F (Track 2: クラウド・データ)",
        "シマブン 11F (Track 3: 組織変革・育成)",
        "シマブン 11F (Track 4: レガシー・刷新)",
        "神鋼ビル 6階 研修室 (ワークショップ)"
    ]

    let wsRooms = [
        "神鋼ビル 6階 (WS 小部屋1: BI実践入門)",
        "神鋼ビル 6階 (WS 小部屋2: Bobスキル作成)",
        "神鋼ビル 6階 (WS 小部屋3: 公募枠③)"
    ]

    var currentActiveRoom: String {
        if selectedVenue.contains("神鋼ビル") {
            return selectedWsRoom
        }
        return selectedVenue
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.07, blue: 0.12).edgesIgnoringSafeArea(.all)

                VStack(spacing: 16) {
                    // 会場選択
                    VStack(alignment: .leading, spacing: 6) {
                        Text("📍 受付部屋 / トラック")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)

                        Picker("会場", selection: $selectedVenue) {
                            ForEach(venues, id: \.self) { v in
                                Text(v).tag(v)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.12, green: 0.16, blue: 0.25))
                        .cornerRadius(10)
                        .foregroundColor(.cyan)

                        // 神鋼ビルの場合のみ小部屋切替ボタンを表示
                        if selectedVenue.contains("神鋼ビル") {
                            Text("👉 参加する小部屋を選択 (ワンタップ切替)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                                .padding(.top, 4)

                            Picker("小部屋", selection: $selectedWsRoom) {
                                Text("小部屋1 (BI)").tag(wsRooms[0])
                                Text("小部屋2 (Bob)").tag(wsRooms[1])
                                Text("小部屋3 (枠③)").tag(wsRooms[2])
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                    .padding()
                    .background(Color(red: 0.08, green: 0.11, blue: 0.18))
                    .cornerRadius(16)

                    // 統計カード
                    HStack {
                        VStack(alignment: .leading) {
                            Text("この端末の累計スキャン")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .fontWeight(.bold)
                            Text("\(scanLogs.count) 件")
                                .font(.system(size: 28, weight: .black))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text("ローカル保存中")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.3))
                            .foregroundColor(.cyan)
                            .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(red: 0.08, green: 0.11, blue: 0.18))
                    .cornerRadius(16)

                    // スキャン結果表示
                    VStack(spacing: 6) {
                        if !lastScannedId.isEmpty {
                            Text("スキャン完了")
                                .font(.caption)
                                .fontWeight(.black)
                                .foregroundColor(.green)
                            Text(lastScannedId)
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                            Text("\(lastScannedTime) [\(currentActiveRoom)]")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        } else {
                            Text("待機中")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                            Text(statusMessage)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color(red: 0.12, green: 0.16, blue: 0.25))
                    .cornerRadius(18)

                    // NFC起動ボタン
                    Button(action: startScan) {
                        HStack {
                            Image(systemName: "wave.3.right.circle.fill")
                                .font(.title2)
                            Text("社員証をスキャンする")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color(red: 0, green: 0.3, blue: 0.8)]), startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(18)
                        .shadow(color: .blue.opacity(0.4), radius: 8, y: 4)
                    }

                    // 直近ログ一覧
                    VStack(alignment: .leading, spacing: 6) {
                        Text("直近のスキャン履歴 (最新順)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .fontWeight(.bold)

                        List(scanLogs.reversed().prefix(5)) { log in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(log.cardId)
                                        .font(.system(.subheadline, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(.cyan)
                                    Text(log.room)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Text(log.timestamp.components(separatedBy: " ").last ?? "")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .listRowBackground(Color(red: 0.08, green: 0.11, blue: 0.18))
                        }
                        .listStyle(PlainListStyle())
                    }

                    // CSV共有送信ボタン
                    Button(action: exportCSV) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("ログをCSV共有・PCへ送信")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.02, green: 0.5, blue: 0.8))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                }
                .padding()
            }
            .navigationTitle("TECH SHARE 受付")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingShareSheet) {
                if let url = shareURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
        .onAppear(perform: loadLogs)
    }

    func startScan() {
        nfcReader.scan { cardId in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let nowStr = formatter.string(from: Date())

            let entry = ScanLog(timestamp: nowStr, room: currentActiveRoom, cardId: cardId)
            DispatchQueue.main.async {
                self.scanLogs.append(entry)
                self.lastScannedId = cardId
                self.lastScannedTime = nowStr
                self.statusMessage = "受付完了: \(cardId)"
                self.saveLogs()
            }
        }
    }

    func saveLogs() {
        if let encoded = try? JSONEncoder().encode(scanLogs) {
            UserDefaults.standard.set(encoded, forKey: "TECHSHARE_LOGS")
        }
    }

    func loadLogs() {
        if let data = UserDefaults.standard.data(forKey: "TECHSHARE_LOGS"),
           let decoded = try? JSONDecoder().decode([ScanLog].self, from: data) {
            self.scanLogs = decoded
        }
    }

    func exportCSV() {
        guard !scanLogs.isEmpty else { return }
        var csv = "\u{FEFF}日時,部屋_トラック,カードID\n"
        for log in scanLogs {
            csv += "\"\(log.timestamp)\",\"\(log.room)\",\"\(log.cardId)\"\n"
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("techshare_logs_\(Int(Date().timeIntervalSince1970)).csv")
        try? csv.write(to: fileURL, atomically: true, encoding: .utf8)

        self.shareURL = fileURL
        self.isShowingShareSheet = true
    }
}

// iOS Native CoreNFC (FeliCa / NFC両対応)
class NFCReader: NSObject, NFCTagReaderSessionDelegate, NFCNDEFReaderSessionDelegate, ObservableObject {
    var session: NFCTagReaderSession?
    var ndefSession: NFCNDEFReaderSession?
    var onScanned: ((String) -> Void)?

    func scan(completion: @escaping (String) -> Void) {
        self.onScanned = completion
        
        if NFCNDEFReaderSession.readingAvailable {
            ndefSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
            ndefSession?.alertMessage = "社員証をiPhone上部にかざしてください"
            ndefSession?.begin()
            return
        }

        if NFCTagReaderSession.readingAvailable {
            session = NFCTagReaderSession(pollingOption: [.iso18092, .iso14443], delegate: self, queue: nil)
            session?.alertMessage = "社員証をiPhone上部にかざしてください"
            session?.begin()
        }
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        self.ndefSession = nil
    }
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // NDEF読み取り時
        if let firstMsg = messages.first, let record = firstMsg.records.first {
            let payload = String(data: record.payload, encoding: .utf8) ?? "NDEF_TAG"
            DispatchQueue.main.async {
                self.onScanned?(payload)
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let firstTag = tags.first else { return }
        session.connect(to: firstTag) { error in
            if error != nil {
                session.invalidate(errorMessage: "読み取りエラー")
                return
            }
            // IDm / UID 取得 (NDEFTag)
            var cardId = "SCANNED_NFC"
            session.alertMessage = "受付完了"
            session.invalidate()
            DispatchQueue.main.async {
                self.onScanned?(cardId)
            }
        }
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        self.session = nil
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let firstTag = tags.first else { return }
        session.connect(to: firstTag) { error in
            if error != nil {
                session.invalidate(errorMessage: "読み取りに失敗しました")
                return
            }

            var cardIdentifier = ""
            switch firstTag {
            case .feliCa(let feliCaTag):
                // FeliCa IDm
                cardIdentifier = feliCaTag.currentIDm.map { String(format: "%02X", $0) }.joined()
            case .miFare(let miFareTag):
                // NFC Type-A UID
                cardIdentifier = miFareTag.identifier.map { String(format: "%02X", $0) }.joined()
            case .iso7816(let isoTag):
                cardIdentifier = isoTag.identifier.map { String(format: "%02X", $0) }.joined()
            default:
                cardIdentifier = "UNKNOWN_TAG"
            }

            session.alertMessage = "スキャン完了: \(cardIdentifier)"
            session.invalidate()

            if let cb = self.onScanned {
                cb(cardIdentifier)
            }
        }
    }
}

// 共有シート
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
