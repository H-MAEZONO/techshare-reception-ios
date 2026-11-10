from typing import List, Optional
import requests
from conference_reception.core.models import Attendee, AttendeeStatus, ScanResult
from conference_reception.ports.interfaces import AttendeeRepositoryPort, ReceptionAuditLogPort

class SharePointAttendeeRepository(AttendeeRepositoryPort):
    """Microsoft Graph API / SharePoint REST API を経由してリストを読み書きするアダプター。
    M365クラウド本番へのシームレスな同期を実現。
    """

    def __init__(self, site_url: str, list_title: str = "ConferenceAttendees", access_token: str = ""):
        self.site_url = site_url.rstrip("/")
        self.list_title = list_title
        self.access_token = access_token
        self.headers = {
            "Accept": "application/json;odata=verbose",
            "Content-Type": "application/json;odata=verbose",
        }
        if access_token:
            self.headers["Authorization"] = f"Bearer {access_token}"

    def find_by_card_id(self, card_id: str) -> Optional[Attendee]:
        endpoint = f"{self.site_url}/_api/web/lists/getbytitle('{self.list_title}')/items?$filter=CardID eq '{card_id}'"
        res = requests.get(endpoint, headers=self.headers, timeout=10)
        res.raise_for_status()
        data = res.json()
        results = data.get("d", {}).get("results", [])
        if not results:
            return None
        return self._to_attendee(results[0])

    def find_by_employee_id(self, employee_id: str) -> Optional[Attendee]:
        endpoint = f"{self.site_url}/_api/web/lists/getbytitle('{self.list_title}')/items?$filter=Title eq '{employee_id}'"
        res = requests.get(endpoint, headers=self.headers, timeout=10)
        res.raise_for_status()
        data = res.json()
        results = data.get("d", {}).get("results", [])
        if not results:
            return None
        return self._to_attendee(results[0])

    def update_attendee(self, attendee: Attendee) -> Attendee:
        # まず既存アイテムのIDを取得
        endpoint_find = f"{self.site_url}/_api/web/lists/getbytitle('{self.list_title}')/items?$filter=Title eq '{attendee.employee_id}'"
        res_find = requests.get(endpoint_find, headers=self.headers, timeout=10)
        res_find.raise_for_status()
        items = res_find.json().get("d", {}).get("results", [])
        if not items:
            raise ValueError(f"Attendee with Title={attendee.employee_id} not found in SharePoint.")

        item_id = items[0]["ID"]
        endpoint_update = f"{self.site_url}/_api/web/lists/getbytitle('{self.list_title}')/items({item_id})"
        update_headers = dict(self.headers)
        update_headers["X-HTTP-Method"] = "MERGE"
        update_headers["If-Match"] = "*"

        payload = {
            "__metadata": {"type": f"SP.Data.{self.list_title}ListItem"},
            "Status": attendee.status.value,
            "CheckInTime": attendee.check_in_time.isoformat() if attendee.check_in_time else None,
            "ReceptionDesk": attendee.reception_desk,
            "Remarks": attendee.remarks
        }
        res_patch = requests.post(endpoint_update, json=payload, headers=update_headers, timeout=10)
        res_patch.raise_for_status()
        return attendee

    def list_all(self) -> List[Attendee]:
        endpoint = f"{self.site_url}/_api/web/lists/getbytitle('{self.list_title}')/items?$top=5000"
        res = requests.get(endpoint, headers=self.headers, timeout=10)
        res.raise_for_status()
        results = res.json().get("d", {}).get("results", [])
        return [self._to_attendee(r) for r in results]

    def bulk_upsert(self, attendees: List[Attendee]) -> int:
        count = 0
        for a in attendees:
            # 既存確認
            existing = self.find_by_employee_id(a.employee_id)
            if existing:
                self.update_attendee(a)
            else:
                endpoint_create = f"{self.site_url}/_api/web/lists/getbytitle('{self.list_title}')/items"
                payload = {
                    "__metadata": {"type": f"SP.Data.{self.list_title}ListItem"},
                    "Title": a.employee_id,
                    "FullName": a.full_name,
                    "Department": a.department,
                    "CardID": a.card_id,
                    "Status": a.status.value,
                    "ReceptionDesk": a.reception_desk,
                    "Remarks": a.remarks
                }
                res = requests.post(endpoint_create, json=payload, headers=self.headers, timeout=10)
                res.raise_for_status()
            count += 1
        return count

    def _to_attendee(self, sp_item: dict) -> Attendee:
        return Attendee(
            employee_id=sp_item.get("Title", ""),
            full_name=sp_item.get("FullName", ""),
            department=sp_item.get("Department", ""),
            card_id=sp_item.get("CardID"),
            status=AttendeeStatus(sp_item.get("Status", "未出席")),
            check_in_time=sp_item.get("CheckInTime"),
            receptionist=sp_item.get("Receptionist", {}).get("Title") if isinstance(sp_item.get("Receptionist"), dict) else None,
            reception_desk=sp_item.get("ReceptionDesk"),
            remarks=sp_item.get("Remarks", "")
        )
