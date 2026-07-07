import logging
import os
import queue
import threading
from dataclasses import dataclass

from django.conf import settings

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class VoiceCallJob:
    incident_id: str
    latitude: float
    longitude: float
    reporter_phone: str


_call_queue: "queue.Queue[VoiceCallJob]" = queue.Queue()
_worker_started = False
_worker_lock = threading.Lock()


def start_worker() -> None:
    global _worker_started
    should_start_in_debug = os.environ.get("RUN_MAIN") == "true"
    if settings.DEBUG and not should_start_in_debug:
        return

    with _worker_lock:
        if _worker_started:
            return
        worker = threading.Thread(
            target=_worker_loop,
            name="twilio-voice-call-worker",
            daemon=True,
        )
        worker.start()
        _worker_started = True


def enqueue_voice_call(job: VoiceCallJob) -> None:
    _call_queue.put(job)


def _worker_loop() -> None:
    while True:
        job = _call_queue.get()
        try:
            _dispatch_twilio_call(job)
        except Exception:
            logger.exception("Unable to dispatch voice call for incident %s", job.incident_id)
        finally:
            _call_queue.task_done()


def _dispatch_twilio_call(job: VoiceCallJob) -> None:
    if not settings.TWILIO_ENABLED:
        logger.info(
            "Twilio disabled. Stub call for incident %s at %s,%s from %s",
            job.incident_id,
            job.latitude,
            job.longitude,
            job.reporter_phone or "anonymous",
        )
        return

    missing = [
        name
        for name, value in {
            "TWILIO_ACCOUNT_SID": settings.TWILIO_ACCOUNT_SID,
            "TWILIO_AUTH_TOKEN": settings.TWILIO_AUTH_TOKEN,
            "TWILIO_FROM_NUMBER": settings.TWILIO_FROM_NUMBER,
            "TWILIO_POLICE_NUMBER": settings.TWILIO_POLICE_NUMBER,
        }.items()
        if not value
    ]
    if missing:
        raise RuntimeError(f"Twilio is enabled but missing: {', '.join(missing)}")

    from twilio.rest import Client

    client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
    message = (
        "Emergency mobility alert. "
        f"Incident {job.incident_id}. "
        f"Coordinates {job.latitude}, {job.longitude}."
    )
    client.calls.create(
        twiml=f"<Response><Say>{message}</Say></Response>",
        to=settings.TWILIO_POLICE_NUMBER,
        from_=settings.TWILIO_FROM_NUMBER,
    )
