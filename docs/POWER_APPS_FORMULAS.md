# Power Apps 実装用 Power Fx コード＆コンポーネント定義書

本ドキュメントは、Microsoft Power Apps Studio でアプリを構築する際にそのまま貼り付けて利用できる Power Fx コードおよびプロパティ設定の一覧です。

---

## 1. データ接続
アプリの左側メニュー「データ」から、以下の SharePoint リストをデータソースとして追加します。
- `ConferenceAttendees` (参加者・出席管理マスタ)
- `ReceptionLogs` (受付ログ / 任意)

---

## 2. アプリ全体の初期化 (`App.OnStart`)
```powerfx
// アプリ起動時の初期化
Set(gblLastScan, Blank());
Set(gblScanStatus, "READY"); // READY, SUCCESS, ALREADY_CHECKED, NOT_FOUND, ERROR
Set(gblCurrentDesk, "受付1"); // 端末ごとに設定（受付1, 受付2 など）
```

---

## 3. 「社員証をタッチして受付」ボタン (`btnScan.OnSelect`)
```powerfx
// 1. NFC読み取り起動（スマホのNFCリーダーが立ち上がります）
Set(locNFC, ReadNFC());

// 2. 読み取り結果の判定処理
If(
    !IsBlank(locNFC.Identifier),
    
    // カードID（FeliCa IDm / NFC UID）で名簿マスタを検索
    Set(locTargetUser, LookUp(ConferenceAttendees, CardID = locNFC.Identifier));

    If(
        // 名簿にカードが存在する場合
        !IsBlank(locTargetUser.Title),
        
        // 【分岐A】既に受付済みの場合
        If(
            locTargetUser.Status.Value = "出席",
            Set(gblLastScan, locTargetUser);
            Set(gblScanStatus, "ALREADY_CHECKED");
            Notify(
                locTargetUser.FullName & " さんは既に受付済みです（" & Text(locTargetUser.CheckInTime, "hh:mm") & "）",
                NotificationType.Warning
            ),
            
            // 【分岐B】正常受付（未受付の場合）
            Patch(
                ConferenceAttendees,
                locTargetUser,
                {
                    Status: { Value: "出席" },
                    CheckInTime: Now(),
                    Receptionist: User(),
                    ReceptionDesk: { Value: gblCurrentDesk }
                }
            );
            // 最新レコードを再取得して画面反映
            Set(gblLastScan, LookUp(ConferenceAttendees, Title = locTargetUser.Title));
            Set(gblScanStatus, "SUCCESS");
            Notify(locTargetUser.FullName & " さんの受付が完了しました", NotificationType.Success)
        ),
        
        // 【分岐C】名簿に存在しない未登録カードの場合
        Set(gblLastScan, { CardID: locNFC.Identifier });
        Set(gblScanStatus, "NOT_FOUND");
        Notify("未登録のカードです（ID: " & locNFC.Identifier & "）", NotificationType.Error)
    )
);

// 3. （任意）監査ログ記録
If(
    !IsBlank(locNFC.Identifier),
    Patch(
        ReceptionLogs,
        Defaults(ReceptionLogs),
        {
            Title: locNFC.Identifier,
            ScanResult: { Value: If(gblScanStatus = "SUCCESS", "成功", If(gblScanStatus = "ALREADY_CHECKED", "重複スキャン", "未登録カード")) },
            MatchedEmployee: If(!IsBlank(locTargetUser.Title), locTargetUser.Title, ""),
            Timestamp: Now(),
            Operator: User().FullName
        }
    )
);
```

---

## 4. UIコントロールのプロパティ設定

### 4.1 結果カード背景色 (`conResultCard.Fill`)
```powerfx
Switch(
    gblScanStatus,
    "SUCCESS", ColorValue("#D4EDDA"),         // 薄いグリーン（成功）
    "ALREADY_CHECKED", ColorValue("#FFF3CD"), // 薄いイエロー（重複注意）
    "NOT_FOUND", ColorValue("#F8D7DA"),       // 薄いレッド（未登録エラー）
    ColorValue("#F8F9FA")                     // デフォルトグレー
)
```

### 4.2 結果カード文字表示 (`lblResultName.Text`)
```powerfx
If(
    gblScanStatus = "SUCCESS",
    gblLastScan.FullName & " 様",
    If(
        gblScanStatus = "ALREADY_CHECKED",
        gblLastScan.FullName & " 様 (受付済)",
        If(
            gblScanStatus = "NOT_FOUND",
            "未登録のカードです",
            "カードをタッチしてください"
        )
    )
)
```

### 4.3 リアルタイム出席集計表示 (`lblStats.Text`)
```powerfx
"出席: " & 
CountRows(Filter(ConferenceAttendees, Status.Value = "出席")) & 
" / " & 
CountRows(ConferenceAttendees) & 
" 名 (" & 
Text(
    If(
        CountRows(ConferenceAttendees) > 0,
        CountRows(Filter(ConferenceAttendees, Status.Value = "出席")) / CountRows(ConferenceAttendees) * 100,
        0
    ),
    "0.0"
) & "%)"
```

### 4.4 直近受付者ギャラリー (`galRecentAttendees.Items`)
```powerfx
FirstN(
    Sort(
        Filter(ConferenceAttendees, Status.Value = "出席"),
        CheckInTime,
        SortOrder.Descending
    ),
    5
)
```
