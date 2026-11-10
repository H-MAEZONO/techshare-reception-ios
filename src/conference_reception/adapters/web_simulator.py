import http.server
import socketserver
import json
import urllib.parse
from datetime import datetime
from conference_reception.core.models import Attendee, AttendeeStatus
from conference_reception.core.service import ReceptionService
from conference_reception.adapters.in_memory import InMemoryAttendeeRepository, InMemoryAuditLogger

SAMPLE_ATTENDEES = [
    Attendee(employee_id="E10001", full_name="山田 太郎", department="技術推進部", card_id="0102030405060708", status=AttendeeStatus.NOT_ATTENDED),
    Attendee(employee_id="E10002", full_name="佐藤 花子", department="総務人事部", card_id="0203040506070809", status=AttendeeStatus.NOT_ATTENDED),
    Attendee(employee_id="E10003", full_name="鈴木 一郎", department="デジタルイノベーション部", card_id="030405060708090A", status=AttendeeStatus.ATTENDED, check_in_time=datetime(2026, 11, 10, 9, 30, 0)),
    Attendee(employee_id="E10004", full_name="高橋 美咲", department="事業開発部", card_id="0405060708090A0B", status=AttendeeStatus.NOT_ATTENDED),
    Attendee(employee_id="E10005", full_name="田中 健一", department="セキュリティ推進室", card_id="05060708090A0B0C", status=AttendeeStatus.NOT_ATTENDED),
]

repository = InMemoryAttendeeRepository(SAMPLE_ATTENDEES)
audit_logger = InMemoryAuditLogger()
service = ReceptionService(repository=repository, audit_logger=audit_logger)

HTML_PAGE = """<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>カンファレンス受付シミュレーター</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; }
        body { background-color: #f4f6f8; display: flex; justify-content: center; align-items: flex-start; min-height: 100vh; padding: 20px; }
        .mobile-container { width: 100%; max-width: 440px; background: #ffffff; border-radius: 28px; box-shadow: 0 12px 30px rgba(0,0,0,0.1); overflow: hidden; display: flex; flex-direction: column; }
        .header { background: #0078d4; color: white; padding: 20px; text-align: center; }
        .header h1 { font-size: 1.25rem; font-weight: 600; }
        .header p { font-size: 0.85rem; opacity: 0.9; margin-top: 4px; }
        .content { padding: 20px; display: flex; flex-direction: column; gap: 16px; }
        
        .stats-card { background: #f8f9fa; border: 1px solid #e2e8f0; border-radius: 14px; padding: 14px; text-align: center; }
        .stats-title { font-size: 0.8rem; color: #64748b; font-weight: 500; }
        .stats-value { font-size: 1.5rem; font-weight: 700; color: #1e293b; margin: 4px 0; }
        .stats-progress { font-size: 0.85rem; color: #0078d4; font-weight: 600; }

        .scan-action-area { display: flex; flex-direction: column; gap: 10px; }
        .btn-scan { background: #0078d4; color: white; border: none; padding: 18px; border-radius: 16px; font-size: 1.15rem; font-weight: 600; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 8px; box-shadow: 0 4px 12px rgba(0,120,212,0.3); transition: transform 0.1s; }
        .btn-scan:active { transform: scale(0.98); }
        .quick-buttons { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
        .btn-quick { background: #e0f2fe; color: #0369a1; border: 1px solid #bae6fd; padding: 10px; border-radius: 10px; font-size: 0.8rem; font-weight: 600; cursor: pointer; }
        .btn-quick:hover { background: #bae6fd; }

        .result-card { border-radius: 16px; padding: 18px; display: none; flex-direction: column; gap: 6px; animation: fadeIn 0.3s; }
        .result-card.SUCCESS { background: #d4edda; border: 1px solid #c3e6cb; color: #155724; display: flex; }
        .result-card.ALREADY_CHECKED { background: #fff3cd; border: 1px solid #ffeeba; color: #856404; display: flex; }
        .result-card.NOT_FOUND { background: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; display: flex; }
        .result-card.ERROR { background: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; display: flex; }
        .result-badge { font-size: 0.75rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; }
        .result-name { font-size: 1.35rem; font-weight: 700; }
        .result-detail { font-size: 0.85rem; opacity: 0.85; }

        .recent-section { margin-top: 10px; }
        .recent-title { font-size: 0.85rem; font-weight: 600; color: #475569; margin-bottom: 8px; }
        .recent-list { list-style: none; display: flex; flex-direction: column; gap: 6px; }
        .recent-item { background: #f8f9fa; border: 1px solid #edf2f7; padding: 10px 14px; border-radius: 10px; display: flex; justify-content: space-between; align-items: center; font-size: 0.85rem; }
        .recent-item .name { font-weight: 600; color: #1e293b; }
        .recent-item .dept { font-size: 0.75rem; color: #64748b; }
        .recent-item .time { font-size: 0.8rem; color: #0284c7; font-weight: 500; }

        @keyframes fadeIn { from { opacity: 0; transform: translateY(-4px); } to { opacity: 1; transform: translateY(0); } }
    </style>
</head>
<body>
    <div class="mobile-container">
        <div class="header">
            <h1>カンファレンス受付</h1>
            <p>社員証（NFC / FeliCa）出席管理システム</p>
        </div>
        <div class="content">
            <div class="stats-card">
                <div class="stats-title">リアルタイム出席状況</div>
                <div class="stats-value" id="statsNumbers">-- / -- 名</div>
                <div class="stats-progress" id="statsRate">出席率: --%</div>
            </div>

            <div id="resultCard" class="result-card">
                <div class="result-badge" id="resStatusBadge">SUCCESS</div>
                <div class="result-name" id="resName">--</div>
                <div class="result-detail" id="resDetail">--</div>
            </div>

            <div class="scan-action-area">
                <button class="btn-scan" onclick="triggerManualScan()">
                    <span>📱</span>
                    <span>社員証をタッチして受付</span>
                </button>
                <div class="quick-buttons">
                    <button class="btn-quick" onclick="simulateScan('0102030405060708')">テスト1: 山田 太郎</button>
                    <button class="btn-quick" onclick="simulateScan('0203040506070809')">テスト2: 佐藤 花子</button>
                    <button class="btn-quick" onclick="simulateScan('030405060708090A')">テスト3: 鈴木(重複)</button>
                    <button class="btn-quick" onclick="simulateScan('UNKNOWN_CARD_99')">テスト4: 未登録カード</button>
                </div>
            </div>

            <div class="recent-section">
                <div class="recent-title">直近の受付完了者</div>
                <ul class="recent-list" id="recentList">
                </ul>
            </div>
        </div>
    </div>

    <script>
        async function fetchStats() {
            const res = await fetch('/api/stats');
            const data = await res.json();
            document.getElementById('statsNumbers').textContent = `${data.attended_count} / ${data.total_count} 名`;
            document.getElementById('statsRate').textContent = `出席率: ${data.attendance_rate}%`;
            
            const listRes = await fetch('/api/attendees');
            const listData = await listRes.json();
            const recent = listData.filter(a => a.status === '出席').reverse().slice(0, 5);
            const ul = document.getElementById('recentList');
            ul.innerHTML = '';
            if (recent.length === 0) {
                ul.innerHTML = '<li class="recent-item" style="justify-content:center;color:#94a3b8;">受付完了者はまだいません</li>';
            } else {
                recent.forEach(r => {
                    const li = document.createElement('li');
                    li.className = 'recent-item';
                    const time = r.check_in_time ? r.check_in_time.split('T')[1].substring(0, 5) : '';
                    li.innerHTML = `<div><div class="name">${r.full_name}</div><div class="dept">${r.department || ''}</div></div><div class="time">${time}</div>`;
                    ul.appendChild(li);
                });
            }
        }

        async function simulateScan(cardId) {
            const res = await fetch('/api/checkin', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ card_id: cardId, receptionist: '受付1 (スマホA)' })
            });
            const data = await res.json();
            showResult(data);
            await fetchStats();
        }

        function triggerManualScan() {
            const cardId = prompt('NFCスキャンシミュレート: カードID (FeliCa IDm/UID) を入力してください:', '0102030405060708');
            if (cardId) {
                simulateScan(cardId);
            }
        }

        function showResult(data) {
            const card = document.getElementById('resultCard');
            card.className = 'result-card ' + data.status;
            document.getElementById('resStatusBadge').textContent = data.status;
            
            if (data.status === 'SUCCESS') {
                document.getElementById('resName').textContent = data.attendee.full_name + ' 様';
                document.getElementById('resDetail').textContent = `${data.attendee.department || ''} (${data.attendee.employee_id}) - 受付完了`;
            } else if (data.status === 'ALREADY_CHECKED') {
                document.getElementById('resName').textContent = data.attendee.full_name + ' 様（受付済）';
                document.getElementById('resDetail').textContent = data.message;
            } else {
                document.getElementById('resName').textContent = '⚠️ 照合エラー';
                document.getElementById('resDetail').textContent = data.message;
            }
        }

        fetchStats();
    </script>
</body>
</html>
"""

class ReceptionSimulatorHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        if url.path == "/" or url.path == "/index.html":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_PAGE.encode("utf-8"))
        elif url.path == "/api/stats":
            stats = service.get_statistics()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(json.dumps(stats.model_dump(), ensure_ascii=False).encode("utf-8"))
        elif url.path == "/api/attendees":
            all_attendees = [a.model_dump(mode="json") for a in repository.list_all()]
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(json.dumps(all_attendees, ensure_ascii=False).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        url = urllib.parse.urlparse(self.path)
        if url.path == "/api/checkin":
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length).decode("utf-8")
            payload = json.loads(body) if body else {}
            
            card_id = payload.get("card_id", "")
            receptionist = payload.get("receptionist", "Web Simulator")
            desk = payload.get("reception_desk", "受付1")

            result = service.check_in(card_id=card_id, receptionist=receptionist, reception_desk=desk)

            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(json.dumps(result.model_dump(mode="json"), ensure_ascii=False).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

def run_simulator(port: int = 8085):
    with socketserver.TCPServer(("", port), ReceptionSimulatorHandler) as httpd:
        print(f"Conference Reception Simulator running at http://localhost:{port}")
        httpd.serve_forever()

if __name__ == "__main__":
    run_simulator()
