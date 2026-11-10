<#
.SYNOPSIS
    SharePoint Online リスト（カンファレンス参加者マスタ・生ログ）の自動作成スクリプト
.DESCRIPTION
    PnP PowerShell または CLI for Microsoft 365 を使用して、仕様書（DATA_MODEL.md）で定義された
    リストおよび列定義をSharePointサイトへ自動プロビジョニングします。
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SiteUrl,

    [string]$ListName = "ConferenceAttendees",
    [string]$LogListName = "ReceptionLogs"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " SharePoint Online リスト自動プロビジョニング開始" -ForegroundColor Cyan
Write-Host " 接続先サイト: $SiteUrl" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# PnP.PowerShell モジュールチェック
if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
    Write-Warning "PnP.PowerShell モジュールがインストールされていません。"
    Write-Host "インストールコマンド: Install-Module PnP.PowerShell -Scope CurrentUser"
    Write-Host "※M365管理ポータルから手動作成するか、PnP PowerShell導入後に本スクリプトを実行してください。"
    exit
}

Connect-PnPOnline -Url $SiteUrl -Interactive

# 1. ConferenceAttendees リスト作成
Write-Host "1. $ListName リストを確認/作成中..." -ForegroundColor Green
$list = Get-PnPList -Identity $ListName -ErrorAction SilentlyContinue
if (-not $list) {
    $list = New-PnPList -Title $ListName -Template GenericList
    Write-Host "  $ListName リストを新規作成しました。" -ForegroundColor Green
}

# 列追加
Add-PnPField -List $ListName -DisplayName "氏名" -InternalName "FullName" -Type Text -AddToDefaultView -ErrorAction SilentlyContinue
Add-PnPField -List $ListName -DisplayName "所属部署" -InternalName "Department" -Type Text -AddToDefaultView -ErrorAction SilentlyContinue
Add-PnPField -List $ListName -DisplayName "カードID" -InternalName "CardID" -Type Text -AddToDefaultView -Indexed -ErrorAction SilentlyContinue
Add-PnPField -List $ListName -DisplayName "出席状況" -InternalName "Status" -Type Choice -Choices "未出席","出席","欠席" -DefaultValue "未出席" -AddToDefaultView -ErrorAction SilentlyContinue
Add-PnPField -List $ListName -DisplayName "出席日時" -InternalName "CheckInTime" -Type DateTime -Format DateTime -AddToDefaultView -ErrorAction SilentlyContinue
Add-PnPField -List $ListName -DisplayName "受付担当者" -InternalName "Receptionist" -Type User -AddToDefaultView -ErrorAction SilentlyContinue
Add-PnPField -List $ListName -DisplayName "受付ブース" -InternalName "ReceptionDesk" -Type Choice -Choices "受付1","受付2","受付3" -AddToDefaultView -ErrorAction SilentlyContinue
Add-PnPField -List $ListName -DisplayName "備考" -InternalName "Remarks" -Type Note -AddToDefaultView -ErrorAction SilentlyContinue

# 2. ReceptionLogs リスト作成
Write-Host "2. $LogListName リストを確認/作成中..." -ForegroundColor Green
$logList = Get-PnPList -Identity $LogListName -ErrorAction SilentlyContinue
if (-not $logList) {
    $logList = New-PnPList -Title $LogListName -Template GenericList
    Write-Host "  $LogListName リストを新規作成しました。" -ForegroundColor Green
}

Add-PnPField -List $LogListName -DisplayName "結果" -InternalName "ScanResult" -Type Choice -Choices "成功","重複スキャン","未登録カード","エラー" -AddToDefaultView -ErrorAction SilentlyContinue
Add-PnPField -List $LogListName -DisplayName "該当社員番号" -InternalName "MatchedEmployee" -Type Text -AddToDefaultView -ErrorAction SilentlyContinue
Add-PnPField -List $LogListName -DisplayName "スキャン日時" -InternalName "Timestamp" -Type DateTime -Format DateTime -AddToDefaultView -ErrorAction SilentlyContinue
Add-PnPField -List $LogListName -DisplayName "受付端末担当" -InternalName "Operator" -Type Text -AddToDefaultView -ErrorAction SilentlyContinue

Write-Host "プロビジョニング完了: リストおよびインデックス（CardID）の構成が正常に完了しました。" -ForegroundColor Cyan
