from abc import ABC, abstractmethod
from typing import List, Optional
from conference_reception.core.models import Attendee, ScanResult, ReceptionStats

class AttendeeRepositoryPort(ABC):
    """参加者リポジトリの抽象ポート（SharePointリスト、RDB、インメモリ等を差し替え可能）"""

    @abstractmethod
    def find_by_card_id(self, card_id: str) -> Optional[Attendee]:
        """カードIDで参加者を検索"""
        pass

    @abstractmethod
    def find_by_employee_id(self, employee_id: str) -> Optional[Attendee]:
        """社員番号で参加者を検索"""
        pass

    @abstractmethod
    def update_attendee(self, attendee: Attendee) -> Attendee:
        """参加者情報の更新"""
        pass

    @abstractmethod
    def list_all(self) -> List[Attendee]:
        """全参加者の一覧取得"""
        pass

    @abstractmethod
    def bulk_upsert(self, attendees: List[Attendee]) -> int:
        """一括登録・更新"""
        pass

class ReceptionAuditLogPort(ABC):
    """受付ログの監査記録ポート"""

    @abstractmethod
    def log_scan(self, scan_result: ScanResult, receptionist: str, reception_desk: Optional[str] = None) -> None:
        pass

class NFCReaderPort(ABC):
    """NFC読み取りハードウェア/デバイスの抽象ポート"""

    @abstractmethod
    def read_tag(self) -> Optional[str]:
        """NFCタグ/カードから固有ID（UID/IDm）を取得"""
        pass
