# Power Apps 実装手順書（Implementation Guide）

本手順書に従うことで、Microsoft Power Apps（キャンバスアプリ）を用いた受付アプリを半日程度で構築できます。

---

## 1. 事前準備
1. SharePointサイト上に `ConferenceAttendees` リストを作成する（詳細は [DATA_MODEL.md](./DATA_MODEL.md) 参照）。
2. テスト用データ（社員番号、氏名、テスト用端末で読み取ったカードID）を数件登録しておく。

---

## 2. アプリ基本設計

- **レイアウト形式:** 電話（モバイル向け縦画面）
- **主要コントロール:**
  - `btnScan`: 画面の大半を占める巨大な「タッチして受付」ボタン
  - `lblResultStatus`: 受付ステータス（成功 / 済 / 未登録）
  - `lblResultName`: 氏名・所属の強調表示
  - `galRecent`: 直近の受付完了者リスト（上位5名程度）
  - `lblSummary`: 現在の出席者数 / 全体数

---

## 3. Power Fx 数式実装

### 3.1 アプリ起動時（`App.OnStart`）
```powerfx
// アプリ初期化：直前のスキャン結果変数のクリア
Set(gblLastScan, Blank());
Set(gblScanStatus, "READY"); // READY, SUCCESS, ALREADY_CHECKED, NOT_FOUND, ERROR
```

### 3.2 読み取りボタン（`btnScan.OnSelect`）
```powerfx
// 1. NFC読み取り起動
Set(locNFC, ReadNFC());

// 2. 読み取り結果の判定
If(
    !IsBlank(locNFC.Identifier),
    // カードIDに一致する参加者を検索
    Set(locTargetUser, LookUp(ConferenceAttendees, CardID = locNFC.Identifier));

    If(
        // 名簿にカードIDが存在する場合
        !IsBlank(locTargetUser.Title),
        
        // 既に受付済みかどうか判定
        If(
            locTargetUser.Status.Value = "出席",
            // 既に受付済みのケース（日時は上書きせず通知）
            Set(gblLastScan, locTargetUser);
            Set(gblScanStatus, "ALREADY_CHECKED");
            Notify(locTargetUser.FullName & " さんは既に受付済みです（" & Text(locTargetUser.CheckInTime, "hh:mm") & "）", NotificationType.Warning),
            
            // 未受付の場合（出席登録を実行）
            Patch(
                ConferenceAttendees,
                locTargetUser,
                {
                    Status: { Value: "出席" },
                    CheckInTime: Now(),
                    Receptionist: User()
                }
            );
            // 最新情報を再取得して表示変数にセット
            Set(gblLastScan, LookUp(ConferenceAttendees, Title = locTargetUser.Title));
            Set(gblScanStatus, "SUCCESS");
            Notify(locTargetUser.FullName & " さんの受付が完了しました", NotificationType.Success)
        ),
        
        // 名簿に存在しない未登録カードの場合
        Set(gblLastScan, { CardID: locNFC.Identifier });
        Set(gblScanStatus, "NOT_FOUND");
        Notify("未登録のカードです（ID: " & locNFC.Identifier & "）", NotificationType.Error)
    )
)
```

---

## 4. UI・画面フィードバックの視覚化

### 4.1 結果カードの背景色（`Fill` プロパティ）
```powerfx
Switch(
    gblScanStatus,
    "SUCCESS", ColorValue("#D4EDDA"),         // 薄いグリーン
    "ALREADY_CHECKED", ColorValue("#FFF3CD"), // 薄いイエロー
    "NOT_FOUND", ColorValue("#F8D7DA"),       // 薄いレッド
    ColorValue("#F8F9FA")                     // 通常グレー
)
```

### 4.2 リアルタイム集計表示（`lblSummary.Text`）
```powerfx
"出席状況: " & 
CountRows(Filter(ConferenceAttendees, Status.Value = "出席")) & 
" / " & 
CountRows(ConferenceAttendees) & 
" 名 (" & 
Text(CountRows(Filter(ConferenceAttendees, Status.Value = "出席")) / CountRows(ConferenceAttendees) * 100, "0.0") & 
"%)"
```

---

## 5. 実機テスト手順
1. Power Apps Studio右上の「保存」および「公開」をクリック。
2. iPhone / Android端末に「Power Apps」アプリをインストールし、Microsoft 365アカウントでログイン。
3. 作成したアプリを開き、社員証を端末のNFCリーダー位置にかざして動作（読み取り・二重防止・リスト更新）を確認する。
