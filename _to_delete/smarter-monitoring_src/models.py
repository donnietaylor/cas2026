"""
Data models for the AI-enhanced event pipeline.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class Event:
    id: str
    source: str
    severity: str
    title: str
    description: str
    labels: dict[str, str]
    timestamp: str
    raw: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "source": self.source,
            "severity": self.severity,
            "title": self.title,
            "description": self.description,
            "labels": self.labels,
            "timestamp": self.timestamp,
        }


@dataclass
class Incident:
    id: str
    severity: str
    title: str
    root_cause: str
    recommended_action: str
    related_events: list[str]
    created_at: str
    source_window: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "severity": self.severity,
            "title": self.title,
            "root_cause": self.root_cause,
            "recommended_action": self.recommended_action,
            "related_events": self.related_events,
            "created_at": self.created_at,
            "source_window": self.source_window,
        }
