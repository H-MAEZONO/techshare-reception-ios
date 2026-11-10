from typing import Dict, List, Optional
from conference_reception.core.models import Attendee, ScanResult
from conference_reception.ports.interfaces import (
    AttendeeRepositoryPort,
    ReceptionAuditLogPort,
    NFCReaderPort
)

class InMemoryAttendeeRepository(AttendeeRepositoryPort):
    """ローカル検証・高速ユニットテスト・オフライン検証用のインメモリ実装"""

    def __init__(self, initial_attendees: Optional[List[Attendee]] = None):
        self._by_employee_id: Dict[str, Attendee] = {}
        self._by_card_id: Dict[str, str] = {} # card_id -> employee_id
        if initial_attendees:
            self.bulk_upsert(initial_attendees)

    def find_by_card_id(self, card_id: str) -> Optional[Attendee]:
        emp_id = self._by_card_id.get(card_id)
        if emp_id:
            return self._by_employee_id.get(emp_id)
        return None

    def find_by_employee_id(self, employee_id: str) -> Optional[Attendee]:
        return self._by_employee_id.get(employee_id)

    def update_attendee(self, attendee: Attendee) -> Attendee:
        self._by_employee_id[attendee.employee_id] = attendee
        if attendee.card_id:
            self._by_card_id[attendee.card_id] = attendee.employee_id
        return attendee

    def list_all(self) -> List[Attendee]:
        return list(self._by_employee_id.values())

    def bulk_upsert(self, attendees: List[Attendee]) -> int:
        count = 0
        for a in attendees:
            self.update_attendee(a)
            count += 1
        return count

class InMemoryAuditLogger(ReceptionAuditLogPort):
    def __init__(self):
        self.logs: List[dict] = []

    def log_scan(self, scan_result: ScanResult, receptionist: str, reception_desk: Optional[str] = None) -> None:
        self.logs.append({
            "card_id": scan_result.card_id,
            "status": scan_result.status.value,
            "message": scan_result.message,
            "timestamp": scan_result.scanned_at,
            "receptionist": receptionist,
            "desk": reception_desk,
            "employee_id": scan_result.attendee.employee_id if scan_result.attendee else None
        })

class MockNFCReader(NFCReaderPort):
    def __init__(self, card_queue: Optional[List[str]] = None):
        self.queue = card_queue or []

    def queue_card(self, card_id: str) -> None:
        self.queue.append(card_id)

    def read_tag(self) -> Optional[str]:
        if self.queue:
            return self.queue.pop(0)
        return None
