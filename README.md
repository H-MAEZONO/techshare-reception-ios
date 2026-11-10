# カンファレンス受付システム（社員証NFC出席管理）

## 1. 概要
社内カンファレンスにおける来場者受付を効率化・デジタル化するための出席管理システムです。
来場者が所持する非接触IC社員証（FeliCa / NFC）を受付担当者のスマートフォン（iPhone / Android）で読み取り、リアルタイムに出席者データを集約・一覧確認します。

## 2. システム構成
- **受付端末アプリ**: Microsoft Power Apps（キャンバスアプリ）
- **データ基盤**: Microsoft 365 SharePoint リスト
- **管理・モニタリング画面**: SharePoint リスト ビュー / Excel Online

## 3. ドキュメント一覧
- [REQUIREMENTS.md](./docs/REQUIREMENTS.md): 要求仕様書・システム要件
- [DATA_MODEL.md](./docs/DATA_MODEL.md): データモデル定義（SharePointリスト定義）
- [APP_IMPLEMENTATION_GUIDE.md](./docs/APP_IMPLEMENTATION_GUIDE.md): Power Apps実装手順書（数式・画面設計）
- [OPERATIONAL_GUIDE.md](./docs/OPERATIONAL_GUIDE.md): 当日運用マニュアル・総務連携チェックリスト
