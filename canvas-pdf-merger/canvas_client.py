"""Minimal Canvas LMS REST API client used by the submission merger tool."""

from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any, Iterator
from urllib.parse import urljoin

import requests

DEFAULT_TIMEOUT = 30
MAX_RETRIES = 3


class CanvasAPIError(RuntimeError):
    pass


@dataclass
class Attachment:
    id: int
    filename: str
    content_type: str
    url: str
    size: int

    @property
    def is_pdf(self) -> bool:
        return self.content_type == "application/pdf" or self.filename.lower().endswith(".pdf")


@dataclass
class StudentSubmission:
    user_id: int
    student_name: str
    workflow_state: str
    submitted_at: str | None
    attachments: list[Attachment]

    @property
    def has_submission(self) -> bool:
        return self.workflow_state != "unsubmitted" and self.submitted_at is not None


class CanvasClient:
    def __init__(self, base_url: str, token: str):
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()
        self.session.headers.update({"Authorization": f"Bearer {token}"})

    def _request(self, method: str, url: str, **kwargs) -> requests.Response:
        last_exc: Exception | None = None
        for attempt in range(1, MAX_RETRIES + 1):
            try:
                resp = self.session.request(method, url, timeout=DEFAULT_TIMEOUT, **kwargs)
            except requests.RequestException as exc:
                last_exc = exc
                time.sleep(2 ** attempt)
                continue

            if resp.status_code == 403 and "rate limit" in resp.text.lower():
                time.sleep(2 ** attempt)
                continue
            if resp.status_code >= 500:
                last_exc = CanvasAPIError(f"{resp.status_code} from {url}")
                time.sleep(2 ** attempt)
                continue

            if not resp.ok:
                raise CanvasAPIError(f"Canvas API error {resp.status_code} for {url}: {resp.text[:500]}")
            return resp

        raise CanvasAPIError(f"Request to {url} failed after {MAX_RETRIES} attempts") from last_exc

    def paginated_get(self, path: str, params: dict[str, Any] | None = None) -> Iterator[dict]:
        url = urljoin(self.base_url + "/", path.lstrip("/"))
        while url:
            resp = self._request("GET", url, params=params)
            params = None  # only needed for the first request; the "next" link carries the rest
            data = resp.json()
            if isinstance(data, list):
                yield from data
            else:
                yield data
            url = resp.links.get("next", {}).get("url")

    def get(self, path: str, params: dict[str, Any] | None = None) -> Any:
        url = urljoin(self.base_url + "/", path.lstrip("/"))
        return self._request("GET", url, params=params).json()

    def find_section_id(self, course_id: int, section_name: str) -> int:
        for section in self.paginated_get(f"/api/v1/courses/{course_id}/sections", {"per_page": 100}):
            if section["name"].strip().lower() == section_name.strip().lower():
                return section["id"]
        raise CanvasAPIError(f'No section named "{section_name}" found in course {course_id}')

    def list_section_submissions(self, section_id: int, assignment_id: int) -> list[StudentSubmission]:
        params = {
            "per_page": 100,
            "include[]": "user",
        }
        results: list[StudentSubmission] = []
        for sub in self.paginated_get(
            f"/api/v1/sections/{section_id}/assignments/{assignment_id}/submissions", params
        ):
            user = sub.get("user") or {}
            attachments = [
                Attachment(
                    id=a["id"],
                    filename=a["filename"],
                    content_type=a.get("content-type", ""),
                    url=a["url"],
                    size=a.get("size", 0),
                )
                for a in (sub.get("attachments") or [])
            ]
            results.append(
                StudentSubmission(
                    user_id=sub["user_id"],
                    student_name=user.get("sortable_name") or user.get("name") or f"user_{sub['user_id']}",
                    workflow_state=sub.get("workflow_state", "unsubmitted"),
                    submitted_at=sub.get("submitted_at"),
                    attachments=attachments,
                )
            )
        results.sort(key=lambda s: s.student_name.lower())
        return results

    def download_attachment(self, attachment: Attachment, dest_path: str) -> None:
        resp = self._request("GET", attachment.url, stream=True)
        with open(dest_path, "wb") as fh:
            for chunk in resp.iter_content(chunk_size=1024 * 256):
                fh.write(chunk)
