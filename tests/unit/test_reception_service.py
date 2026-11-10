import pytest
from datetime import datetime
from conference_reception.core.models import Attendee, AttendeeStatus, ScanResultStatus
from conference_reception.core.service import ReceptionService
from conference_reception.adapters.in_memory import InMemoryAttendeeRepository, InMemoryAuditLogger

@pytest.fixture
def sample_attendees():
    return [
        Attendee(
            employee_id="E1001",
            full_name="山田 太郎",
            department="技術推進部",
            card_id="0102030405060708",
            status=AttendeeStatus.NOT_ATTENDED
        ),
        Attendee(
            employee_id="E1002",
            full_name="佐藤 花子",
            department="総務部",
            card_id="0203040506070809",
            status=AttendeeStatus.NOT_ATTENDED
        ),
        Attendee(
            employee_id="E1003",
            full_name="鈴木 一郎",
            department="営業統括部",
            card_id="030405060708090A",
            status=AttendeeStatus.ATTENDED,
            check_in_time=datetime(2026, 11, 10, 9, 30, 0)
        ),
    ]

@pytest.fixture
def service(sample_attendees):
    repo = InMemoryAttendeeRepository(sample_attendees)
    audit = InMemoryAuditLogger()
    return ReceptionService(repository=repo, audit_logger=audit), repo, audit

def test_successful_check_in(service):
    """未受付の出席者が正常に受付完了することの検証"""
    reception_svc, repo, audit = service

    result = reception_svc.check_in(
        card_id="0102030405060708",
        receptionist="受付担当A",
        reception_desk="受付1"
    )

    assert result.status == ScanResultStatus.SUCCESS
    assert "山田 太郎 さんの受付が完了しました" in result.message
    assert result.attendee.status == AttendeeStatus.ATTENDED
    assert result.attendee.check_in_time is not None
    assert result.attendee.receptionist == "受付担当A"
    assert result.attendee.reception_desk == "受付1"

    # リポジトリ内のデータも更新されていること
    updated = repo.find_by_employee_id("E1001")
    assert updated.status == AttendeeStatus.ATTENDED
    assert len(audit.logs) == 1
    assert audit.logs[0]["status"] == "SUCCESS"

def test_duplicate_check_in_protection(service):
    """既に受付済みの出席者を再スキャンした場合、二重受付とならず日時が上書きされないことの検証"""
    reception_svc, repo, audit = service
    original_time = datetime(2026, 11, 10, 9, 30, 0)

    result = reception_svc.check_in(
        card_id="030405060708090A",
        receptionist="受付担当B"
    )

    assert result.status == ScanResultStatus.ALREADY_CHECKED
    assert "既に受付済みです" in result.message
    assert "09:30" in result.message

    # 出席日時は元のまま上書きされていないこと
    attendee = repo.find_by_employee_id("E1003")
    assert attendee.check_in_time == original_time

    assert len(audit.logs) == 1
    assert audit.logs[0]["status"] == "ALREADY_CHECKED"

def test_unregistered_card(service):
    """マスタに存在しないカードをタッチした場合、NOT_FOUNDとなりエラーログが残ることの検証"""
    reception_svc, repo, audit = service

    result = reception_svc.check_in(
        card_id="UNKNOWN_9999",
        receptionist="受付担当A"
    )

    assert result.status == ScanResultStatus.NOT_FOUND
    assert "未登録のカードです（ID: UNKNOWN_9999）" in result.message
    assert result.attendee is None

    assert len(audit.logs) == 1
    assert audit.logs[0]["status"] == "NOT_FOUND"

def test_empty_card_id(service):
    """空のカードIDが渡された場合のガード処理の検証"""
    reception_svc, repo, audit = service

    result = reception_svc.check_in(card_id="")
    assert result.status == ScanResultStatus.ERROR
    assert "空" in result.message

def test_statistics_calculation(service):
    """出席率および集計が正しく計算されることの検証"""
    reception_svc, repo, audit = service

    stats = reception_svc.get_statistics()
    # 初期状態: 全3名中、1名出席、2名未出席
    assert stats.total_count == 3
    assert stats.attended_count == 1
    assert stats.not_attended_count == 2
    assert stats.attendance_rate == 33.3

    # 1人受付
    reception_svc.check_in("0102030405060708")
    stats_after = reception_svc.get_statistics()
    assert stats_after.attended_count == 2
    assert stats_after.not_attended_count == 1
    assert stats_after.attendance_rate == 66.7
