from datetime import datetime
from typing import Optional
from conference_reception.core.models import (
    Attendee,
    AttendeeStatus,
    ScanResult,
    ScanResultStatus,
    ReceptionStats
)
from conference_reception.ports.interfaces import (
    AttendeeRepositoryPort,
    ReceptionAuditLogPort
)

class ReceptionService:
    """カンファレンス受付のドメインビジネスロジック。
    外部インフラ（SharePoint、DB等）に依存せず、純粋な判定・処理ルールをカプセル化する。
    """

    def __init__(
        self,
        repository: AttendeeRepositoryPort,
        audit_logger: Optional[ReceptionAuditLogPort] = None
    ):
        self.repository = repository
        self.audit_logger = audit_logger

    def check_in(
        self,
        card_id: str,
        receptionist: str = "受付端末",
        reception_desk: Optional[str] = None,
        timestamp: Optional[datetime] = None
    ) -> ScanResult:
        """NFCカード読み取りによる受付処理を実行する"""
        card_id_clean = card_id.strip() if card_id else ""
        if not card_id_clean:
            result = ScanResult(
                status=ScanResultStatus.ERROR,
                message="カードIDが空です",
                card_id="",
            )
            return result

        now = timestamp or datetime.now()
        attendee = self.repository.find_by_card_id(card_id_clean)

        # 1. 未登録カード
        if not attendee:
            result = ScanResult(
                status=ScanResultStatus.NOT_FOUND,
                message=f"未登録のカードです（ID: {card_id_clean}）",
                card_id=card_id_clean,
                scanned_at=now
            )
            if self.audit_logger:
                self.audit_logger.log_scan(result, receptionist, reception_desk)
            return result

        # 2. 既に受付済み（二重受付）
        if attendee.status == AttendeeStatus.ATTENDED:
            time_str = attendee.check_in_time.strftime("%H:%M") if attendee.check_in_time else "以前"
            result = ScanResult(
                status=ScanResultStatus.ALREADY_CHECKED,
                message=f"{attendee.full_name} さんは既に受付済みです（{time_str}）",
                card_id=card_id_clean,
                attendee=attendee,
                scanned_at=now
            )
            if self.audit_logger:
                self.audit_logger.log_scan(result, receptionist, reception_desk)
            return result

        # 3. 未受付（正常受付）
        attendee.status = AttendeeStatus.ATTENDED
        attendee.check_in_time = now
        attendee.receptionist = receptionist
        if reception_desk:
            attendee.reception_desk = reception_desk

        updated = self.repository.update_attendee(attendee)

        result = ScanResult(
            status=ScanResultStatus.SUCCESS,
            message=f"{updated.full_name} さんの受付が完了しました",
            card_id=card_id_clean,
            attendee=updated,
            scanned_at=now
        )
        if self.audit_logger:
            self.audit_logger.log_scan(result, receptionist, reception_desk)
        return result

    def get_statistics(self) -> ReceptionStats:
        """リアルタイム出席統計を算出"""
        all_attendees = self.repository.list_all()
        total = len(all_attendees)
        attended = sum(1 for a in all_attendees if a.status == AttendeeStatus.ATTENDED)
        not_attended = total - attended
        rate = (attended / total * 100.0) if total > 0 else 0.0

        return ReceptionStats(
            total_count=total,
            attended_count=attended,
            not_attended_count=not_attended,
            attendance_rate=round(rate, 1)
        )
