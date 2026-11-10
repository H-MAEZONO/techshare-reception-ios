from enum import Enum
from typing import Optional
from datetime import datetime
from pydantic import BaseModel, Field

class AttendeeStatus(str, Enum):
    NOT_ATTENDED = "未出席"
    ATTENDED = "出席"
    ABSENT = "欠席"

class ScanResultStatus(str, Enum):
    SUCCESS = "SUCCESS"
    ALREADY_CHECKED = "ALREADY_CHECKED"
    NOT_FOUND = "NOT_FOUND"
    ERROR = "ERROR"

class Attendee(BaseModel):
    employee_id: str = Field(..., description="社員番号（Title）")
    full_name: str = Field(..., description="氏名")
    department: Optional[str] = Field(default="", description="所属部署")
    card_id: Optional[str] = Field(default=None, description="FeliCa IDm / NFC UID")
    status: AttendeeStatus = Field(default=AttendeeStatus.NOT_ATTENDED, description="出席状況")
    check_in_time: Optional[datetime] = Field(default=None, description="受付日時")
    receptionist: Optional[str] = Field(default=None, description="受付担当者")
    reception_desk: Optional[str] = Field(default=None, description="受付ブース")
    remarks: Optional[str] = Field(default="", description="備考")

class ScanResult(BaseModel):
    status: ScanResultStatus
    message: str
    card_id: str
    attendee: Optional[Attendee] = None
    scanned_at: datetime = Field(default_factory=datetime.now)

class ReceptionStats(BaseModel):
    total_count: int
    attended_count: int
    not_attended_count: int
    attendance_rate: float
