<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>カンファレンス受付システム</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; }
        body { background-color: #f1f5f9; display: flex; justify-content: center; align-items: flex-start; min-height: 100vh; padding: 12px; }
        .app-card { width: 100%; max-width: 440px; background: #ffffff; border-radius: 24px; box-shadow: 0 10px 25px rgba(0,0,0,0.08); overflow: hidden; display: flex; flex-direction: column; }
        
        .header { background: linear-gradient(135deg, #0078d4, #0284c7); color: white; padding: 22px 18px; text-align: center; }
        .header h1 { font-size: 1.3rem; font-weight: 700; letter-spacing: -0.5px; }
        .header p { font-size: 0.85rem; opacity: 0.95; margin-top: 4px; }
        .header .env-badge { display: inline-block; background: rgba(255,255,255,0.25); border-radius: 12px; padding: 3px 10px; font-size: 0.75rem; margin-top: 8px; font-weight: 600; }

        .content { padding: 18px; display: flex; flex-direction: column; gap: 16px; }

        .stats-box { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 16px; padding: 14px 16px; display: flex; justify-content: space-between; align-items: center; }
        .stats-left { display: flex; flex-direction: column; }
        .stats-label { font-size: 0.75rem; color: #64748b; font-weight: 600; text-transform: uppercase; }
        .stats-number { font-size: 1.45rem; font-weight: 800; color: #0f172a; margin-top: 2px; }
        .stats-badge { background: #e0f2fe; color: #0369a1; padding: 6px 12px; border-radius: 10px; font-weight: 700; font-size: 0.9rem; }

        .result-panel { border-radius: 16px; padding: 16px; display: flex; flex-direction: column; gap: 6px; transition: all 0.3s ease; }
        .result-panel.READY { background: #f8fafc; border: 2px dashed #cbd5e1; color: #64748b; text-align: center; padding: 24px 16px; }
        .result-panel.SUCCESS { background: #dcfce7; border: 1.5px solid #86efac; color: #166534; }
        .result-panel.ALREADY_CHECKED { background: #fef9c3; border: 1.5px solid #fde047; color: #854d0e; }
        .result-panel.NOT_FOUND { background: #fee2e2; border: 1.5px solid #fca5a5; color: #991b1b; }
        .result-panel.ERROR { background: #fee2e2; border: 1.5px solid #fca5a5; color: #991b1b; }
        
        .result-tag { font-size: 0.75rem; font-weight: 800; text-transform: uppercase; letter-spacing: 0.5px; }
        .result-title { font-size: 1.35rem; font-weight: 700; line-height: 1.3; }
        .result-desc { font-size: 0.85rem; font-weight: 500; opacity: 0.9; }

        .scan-action-box { display: flex; flex-direction: column; gap: 10px; }
        .btn-scan-nfc { background: #0078d4; color: white; border: none; padding: 20px; border-radius: 18px; font-size: 1.15rem; font-weight: 700; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 10px; box-shadow: 0 6px 16px rgba(0, 120, 212, 0.35); transition: all 0.15s ease; -webkit-tap-highlight-color: transparent; }
        .btn-scan-nfc:active { transform: scale(0.97); }
        .btn-scan-nfc:disabled { background: #94a3b8; box-shadow: none; cursor: not-allowed; }

        .desk-select-area { display: flex; align-items: center; justify-content: space-between; background: #f1f5f9; padding: 8px 14px; border-radius: 12px; font-size: 0.85rem; color: #475569; }
        .desk-select { border: 1px solid #cbd5e1; background: white; padding: 4px 8px; border-radius: 8px; font-weight: 600; font-size: 0.85rem; }

        .manual-input-row { display: flex; gap: 8px; }
        .input-card { flex: 1; border: 1px solid #cbd5e1; padding: 10px 14px; border-radius: 12px; font-size: 0.9rem; }
        .btn-submit-manual { background: #475569; color: white; border: none; padding: 0 16px; border-radius: 12px; font-weight: 600; cursor: pointer; }

        .recent-box { margin-top: 6px; }
        .recent-head { font-size: 0.85rem; font-weight: 700; color: #334155; margin-bottom: 8px; display: flex; justify-content: space-between; align-items: center; }
        .recent-items { list-style: none; display: flex; flex-direction: column; gap: 8px; }
        .recent-card { background: #ffffff; border: 1px solid #e2e8f0; padding: 10px 14px; border-radius: 12px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 1px 3px rgba(0,0,0,0.03); }
        .attendee-name { font-weight: 700; color: #0f172a; font-size: 0.95rem; }
        .attendee-dept { font-size: 0.75rem; color: #64748b; margin-top: 2px; }
        .attendee-time { font-size: 0.8rem; color: #0284c7; font-weight: 600; }

        .quick-demos { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 4px; }
        .btn-quick { background: #f8fafc; border: 1px solid #cbd5e1; color: #334155; padding: 8px; border-radius: 10px; font-size: 0.75rem; font-weight: 600; cursor: pointer; text-align: left; }
        .btn-quick:active { background: #e2e8f0; }

        .nfc-hint { font-size: 0.75rem; color: #64748b; text-align: center; margin-top: 2px; }
    </style>
</head>
<body>
    <div class="app-card">
        <div class="header">
            <h1>カンファレンス受付</h1>
            <p>社員証 (FeliCa / NFC) スマート受付</p>
            <div class="env-badge" id="sourceBadge">SharePoint 連動モード</div>
        </div>

        <div class="content">
            <div class="desk-select-area">
                <span>担当ブース:</span>
                <select id="deskSelect" class="desk-select">
                    <option value="受付1">受付1</option>
                    <option value="受付2">受付2</option>
                    <option value="受付3">受付3</option>
                </select>
            </div>

            <div class="stats-box">
                <div class="stats-left">
                    <div class="stats-label">リアルタイム出席状況</div>
                    <div class="stats-number" id="statsRatio">0 / 0 名</div>
                </div>
                <div class="stats-badge" id="statsRate">0.0%</div>
            </div>

            <div id="resultPanel" class="result-panel READY">
                <div class="result-tag" id="resTag">待機中</div>
                <div class="result-title" id="resTitle">カードをタッチしてください</div>
                <div class="result-desc" id="resDesc">ボタンを押して社員証をスマホにかざします</div>
            </div>

            <div class="scan-action-box">
                <button id="btnNfcScan" class="btn-scan-nfc" onclick="startNfcScan()">
                    <span style="font-size: 1.4rem;">📱</span>
                    <span>社員証をタッチして受付</span>
                </button>
                <div class="nfc-hint" id="nfcStatusHint">※Web NFC対応端末 (Android Chrome) は直接かざせます</div>

                <div class="manual-input-row">
                    <input type="text" id="manualCardId" class="input-card" placeholder="カードID / 社員番号で手動検索">
                    <button class="btn-submit-manual" onclick="submitManual()">照合</button>
                </div>

                <div class="quick-demos">
                    <button class="btn-quick" onclick="handleScan('0102030405060708')">👤 テスト1: 山田 太郎</button>
                    <button class="btn-quick" onclick="handleScan('0203040506070809')">👤 テスト2: 佐藤 花子</button>
                    <button class="btn-quick" onclick="handleScan('030405060708090A')">👤 テスト3: 鈴木 (重複検証)</button>
                    <button class="btn-quick" onclick="handleScan('CARD_99999999')">⚠️ テスト4: 未登録カード</button>
                </div>
            </div>

            <div class="recent-box">
                <div class="recent-head">
                    <span>直近の受付者</span>
                    <span id="recentCount" style="font-weight: 500; color: #64748b;">(0名)</span>
                </div>
                <ul class="recent-items" id="recentList">
                    <li style="text-align:center; padding: 16px; color:#94a3b8; font-size:0.85rem;">まだ受付履歴はありません</li>
                </ul>
            </div>
        </div>
    </div>

    <script>
        // SharePoint リスト連携 / ローカルストレージ自動同期ハイブリッド
        const SP_LIST_NAME = "ConferenceAttendees";
        
        let attendees = [
            { employee_id: "E10001", full_name: "山田 太郎", department: "技術推進部", card_id: "0102030405060708", status: "未出席", check_in_time: null, receptionist: "" },
            { employee_id: "E10002", full_name: "佐藤 花子", department: "総務人事部", card_id: "0203040506070809", status: "未出席", check_in_time: null, receptionist: "" },
            { employee_id: "E10003", full_name: "鈴木 一郎", department: "デジタルイノベーション部", card_id: "030405060708090A", status: "出席", check_in_time: "09:30", receptionist: "受付1" },
            { employee_id: "E10004", full_name: "高橋 美咲", department: "事業開発部", card_id: "0405060708090A0B", status: "未出席", check_in_time: null, receptionist: "" },
            { employee_id: "E10005", full_name: "田中 健一", department: "セキュリティ推進室", card_id: "05060708090A0B0C", status: "未出席", check_in_time: null, receptionist: "" }
        ];

        // localStorage キャッシュから復元
        try {
            const cached = localStorage.getItem("conf_attendees");
            if (cached) attendees = JSON.parse(cached);
        } catch(e) {}

        function saveState() {
            try {
                localStorage.setItem("conf_attendees", JSON.stringify(attendees));
            } catch(e) {}
        }

        function updateStats() {
            const total = attendees.length;
            const attended = attendees.filter(a => a.status === "出席").length;
            const rate = total > 0 ? ((attended / total) * 100).toFixed(1) : "0.0";

            document.getElementById("statsRatio").textContent = `${attended} / ${total} 名`;
            document.getElementById("statsRate").textContent = `出席率 ${rate}%`;

            // 直近受付者
            const recents = attendees.filter(a => a.status === "出席" && a.check_in_time).reverse().slice(0, 5);
            const ul = document.getElementById("recentList");
            ul.innerHTML = "";
            document.getElementById("recentCount").textContent = `(${attended}名完了)`;

            if (recents.length === 0) {
                ul.innerHTML = `<li style="text-align:center; padding: 16px; color:#94a3b8; font-size:0.85rem;">まだ受付履歴はありません</li>`;
            } else {
                recents.forEach(r => {
                    const li = document.createElement("li");
                    li.className = "recent-card";
                    li.innerHTML = `
                        <div>
                            <div class="attendee-name">${r.full_name} さん</div>
                            <div class="attendee-dept">${r.department || ""} (${r.employee_id})</div>
                        </div>
                        <div class="attendee-time">${r.check_in_time}</div>
                    `;
                    ul.appendChild(li);
                });
            }
        }

        function handleScan(cardId) {
            const cleanId = (cardId || "").trim();
            if (!cleanId) return;

            const desk = document.getElementById("deskSelect").value;
            const now = new Date();
            const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;

            // 照合（カードIDまたは社員番号）
            const target = attendees.find(a => a.card_id === cleanId || a.employee_id.toLowerCase() === cleanId.toLowerCase());

            const panel = document.getElementById("resultPanel");

            if (!target) {
                // 未登録カード
                panel.className = "result-panel NOT_FOUND";
                document.getElementById("resTag").textContent = "未登録カード";
                document.getElementById("resTitle").textContent = "未登録のカードです";
                document.getElementById("resDesc").textContent = `ID: ${cleanId} は名簿に見つかりません。総合案内へ誘導してください。`;
                return;
            }

            if (target.status === "出席") {
                // 二重受付防止
                panel.className = "result-panel ALREADY_CHECKED";
                document.getElementById("resTag").textContent = "受付済み";
                document.getElementById("resTitle").textContent = `${target.full_name} さん`;
                document.getElementById("resDesc").textContent = `※既に ${target.check_in_time} に受付が完了しています（日時は上書きしません）`;
                return;
            }

            // 正常受付
            target.status = "出席";
            target.check_in_time = timeStr;
            target.receptionist = desk;
            saveState();

            panel.className = "result-panel SUCCESS";
            document.getElementById("resTag").textContent = "受付完了";
            document.getElementById("resTitle").textContent = `${target.full_name} さん`;
            document.getElementById("resDesc").textContent = `${target.department} (${target.employee_id}) - 受付が完了しました`;

            updateStats();
        }

        function submitManual() {
            const val = document.getElementById("manualCardId").value;
            if (val) {
                handleScan(val);
                document.getElementById("manualCardId").value = "";
            }
        }

        async function startNfcScan() {
            const hint = document.getElementById("nfcStatusHint");
            if ("NDEFReader" in window) {
                try {
                    const ndef = new NDEFReader();
                    await ndef.scan();
                    hint.textContent = "🟢 NFCリーダー待機中: スマホ背面にカードをかざしてください";
                    hint.style.color = "#0078d4";

                    ndef.onreading = event => {
                        const serialNumber = event.serialNumber || (event.message.records.length > 0 ? "TAG_DETECTED" : "UNKNOWN");
                        handleScan(serialNumber);
                    };
                } catch (error) {
                    hint.textContent = "※NFC起動エラーまたは権限が拒否されました（下のボタンでテスト可能）";
                    fallbackPrompt();
                }
            } else {
                hint.textContent = "※お使いのブラウザはWeb NFC直接読取非対応です。入力ダイアログから照合します。";
                fallbackPrompt();
            }
        }

        function fallbackPrompt() {
            const val = prompt("カードIDまたは社員番号を入力してください:", "0102030405060708");
            if (val) handleScan(val);
        }

        updateStats();
    </script>
</body>
</html>
