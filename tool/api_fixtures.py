"""Write backend-shaped API fixtures for the app's contract tests.

Each response fixture is built by validating sample data through the backend's own Pydantic
response model and dumping it the way FastAPI does (`mode="json"`, `by_alias=True`). The output
therefore carries every field, default and alias the backend really sends. Every DTO the app parses
has a fixture here. Request fixtures are the flattened JSON schemas of the bodies the app sends.
Operation fixtures come from `360ghar-backend/docs/openapi.json`.

Run from the app root with the backend environment:

    uv run --project ../360ghar-backend python tool/api_fixtures.py

It imports schemas only: no app start-up, no database, no network. `tool/gen_enums.py` writes
`enums.json` next to these files.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

APP = Path(__file__).resolve().parents[1]
BACKEND = Path(os.environ.get("BACKEND_DIR", APP.parent / "360ghar-backend"))
OUT = APP / "test" / "fixtures" / "api"
sys.path.insert(0, str(BACKEND))

from app.api.api_v1.endpoints.auth import (  # noqa: E402
    DeleteAccountRequest,
    IdentifierStatusRequest,
    IdentifierStatusResponse,
    LastMethodRequest,
)
from app.api.api_v1.endpoints.notifications import (  # noqa: E402
    DeviceRegisterIn,
    DeviceRegistration,
    DeviceUnregisterIn,
)
from app.infrastructure.errors import (  # noqa: E402
    ErrorEnvelope,
    ValidationErrorEnvelope,
    error_body,
    validation_details,
)
from app.schemas.agent import Agent  # noqa: E402
from app.schemas.ai_agent import (  # noqa: E402
    AgentChatRequest,
    AIConversationSummary,
    ConversationInfoData,
    ConversationInfoFrame,
    ConversationMessageOut,
    DoneData,
    DoneFrame,
    ErrorData,
    ErrorFrame,
    TextChunkData,
    TextChunkFrame,
    ToolCallEndData,
    ToolCallEndFrame,
    ToolCallStartData,
    ToolCallStartFrame,
    WidgetFrame,
    make_widget_data,
)
from app.schemas.amenity import Amenity  # noqa: E402
from app.schemas.common import (  # noqa: E402
    NotificationSettings,
    NotificationSettingsWrite,
    PrivacySettings,
)
from app.schemas.core import (  # noqa: E402
    AppVersionCheckRequest,
    AppVersionCheckResponse,
    BugReportCreate,
    BugReportResponse,
    PagePublicResponse,
)
from app.schemas.pagination import CursorPage  # noqa: E402
from app.schemas.property import Property, PropertyDetail  # noqa: E402
from app.schemas.swipe import SwipeCreate, SwipeOut  # noqa: E402
from app.schemas.user import (  # noqa: E402
    LocationUpdate,
    SelfUser,
    UserLocation,
    UserPreferences,
    UserPreferencesPatch,
    UserUpdate,
)
from app.schemas.visit import Visit, VisitCancel, VisitCreate, VisitReschedule  # noqa: E402
from app.services.ai_agent.agent_service import sse_frame  # noqa: E402
from app.services.notification_config import NotificationChannel  # noqa: E402
from app.services.notifications.fcm import build_message  # noqa: E402
from app.services.notifications.helpers import _augment_data_with_meta  # noqa: E402

NOW = "2026-09-30T10:15:02Z"
COMPANY_NUMBER = "+911800000360"


def dump(model_cls, data):
    return model_cls.model_validate(data).model_dump(mode="json", by_alias=True)


def page(model_cls, items, *, next_cursor=None, limit=20, total=None):
    return dump(
        CursorPage[model_cls],
        {
            "items": items,
            "next_cursor": next_cursor,
            "has_more": next_cursor is not None,
            "limit": limit,
            "total": total,
        },
    )


def image(pid: int, slot: int, category: str, *, main: bool = False):
    return {
        "id": pid * 10 + slot,
        "property_id": pid,
        "image_url": f"https://cdn.example.com/p{pid}/{category}-{slot}.jpg",
        "image_category": category,
        "display_order": slot,
        "is_main_image": main,
    }


def prop(pid: int, **extra):
    """A property as the list routes send it: the owner number is already masked."""
    base = {
        "id": pid,
        "owner_id": 7,
        "title": f"3 BHK in Sector {50 + pid}",
        "description": "Corner flat with two balconies and morning light.",
        "property_type": "apartment",
        "purpose": "buy",
        "base_price": 8_500_000,
        "area_sqft": 1450,
        "status": "available",
        "is_available": True,
        "available_from": "2026-11-01T00:00:00Z",
        "view_count": 12,
        "like_count": 3,
        "interest_count": 1,
        "created_at": NOW,
        "updated_at": NOW,
        "city": "Gurugram",
        "locality": f"Sector {50 + pid}",
        "latitude": 28.4231,
        "longitude": 77.0851,
        "bedrooms": 3,
        "bathrooms": 2,
        "main_image_url": f"https://cdn.example.com/p{pid}/main.jpg",
        "owner_name": "Meera Shah",
        # Masked for a viewer who is not the owner: the agent number, else the company number.
        "owner_contact": COMPANY_NUMBER,
        "features": ["Corner unit", "Vastu compliant"],
        # The floor_plan row is split into floor_plans by the Property schema.
        "images": [
            image(pid, 1, "hall", main=True),
            image(pid, 2, "kitchen"),
            image(pid, 3, "floor_plan"),
        ],
        # `id` is the amenity id (the value PUT /properties takes in amenity_ids).
        "amenities": [
            {"id": 11, "title": "Swimming Pool", "icon": "pool", "category": "recreation"},
            {"id": 12, "title": "Power Backup", "icon": "battery", "category": "utilities"},
        ],
    }
    base.update(extra)
    return base


def rent_prop(pid: int, **extra):
    fields = {
        "purpose": "rent",
        "base_price": 0,
        "monthly_rent": 45_000,
        "security_deposit": 90_000,
        "maintenance_charges": 2_500,
    }
    return prop(pid, **{**fields, **extra})


def stay_prop(pid: int, **extra):
    return prop(pid, **{"purpose": "short_stay", "base_price": 0, "daily_rate": 3_500, **extra})


def pg_prop(pid: int, **extra):
    fields = {
        "property_type": "pg",
        "monthly_rent": 12_000,
        "setup_cost": 5_000,
        "other_charges": 1_200,
        "other_charges_description": "Electricity and Wi-Fi",
        "furnishing_level": "semi_furnished",
        "kitchen_type": "vegetarian",
        "ventilation_type": "good",
        "windows_count": 3,
        "ventilation_shafts": 1,
        "max_occupancy": 2,
        "listing_preferences": {
            "gender_preference": "female",
            "sharing_type": "master_bedroom",
            "moderation_status": "live",
        },
    }
    return rent_prop(pid, **{**fields, **extra})


def public_user(uid: int, name: str, avatar: str | None = None):
    return {"id": uid, "display_name": name, "avatar_url": avatar}


def self_user(**extra):
    base = {
        "id": 50,
        "supabase_user_id": "0f5e8d9a-1c2b-4d3e-8f7a-6b5c4d3e2f1a",
        "email": "asha@example.com",
        "phone": "+919800000000",
        "full_name": "Asha Verma",
        "date_of_birth": "1994-02-11",
        "role": "user",
        "is_active": True,
        "is_verified": True,
        "phone_verified": True,
        "email_verified": False,
        "last_auth_method": "phone_otp",
        "last_auth_method_at": NOW,
        "profile_image_url": "https://cdn.example.com/u/50.jpg",
        "preferences": {"purpose": "rent", "property_type": ["apartment"], "max_distance_km": 5},
        "current_latitude": 28.42,
        "current_longitude": 77.08,
        "notification_settings": {"push_notifications": True, "promotional_emails": False},
        "privacy_settings": {"profile_visibility": "agents_only"},
        "agent_id": 4,
        "created_at": NOW,
        "updated_at": NOW,
    }
    base.update(extra)
    return base


def visit(vid: int, **extra):
    base = {
        "id": vid,
        "property_id": 1,
        "user_id": 50,
        "scheduled_date": "2026-10-04T05:30:00Z",
        "time_slot_label": "morning",
        "status": "requested",
        "created_at": NOW,
        "updated_at": NOW,
        "agent_id": 4,
        "agents": {"id": 4, "name": "Ravi Kumar", "phone": "+919811111111"},
        "property": prop(1),
        "user": public_user(50, "Asha Verma", "https://cdn.example.com/u/50.jpg"),
    }
    base.update(extra)
    return base


def flatten_request(model_cls) -> dict[str, Any]:
    """The request body contract the app must satisfy: required keys, strictness, key limits."""
    schema = model_cls.model_json_schema(mode="validation")
    defs = schema.get("$defs", {})

    def resolve(node: dict[str, Any]) -> tuple[dict[str, Any], bool]:
        nullable = False
        while True:
            if "$ref" in node:
                node = defs[node["$ref"].split("/")[-1]]
            elif "anyOf" in node:
                members = [m for m in node["anyOf"] if m.get("type") != "null"]
                nullable = nullable or len(members) != len(node["anyOf"])
                node = members[0]
            else:
                return node, nullable

    properties: dict[str, Any] = {}
    for name, raw in schema.get("properties", {}).items():
        node, nullable = resolve(raw)
        info = {
            key: node[key]
            for key in ("enum", "maxLength", "minLength", "maximum", "minimum", "type")
            if key in node
        }
        info["nullable"] = nullable
        if "properties" in node:
            info["properties"] = sorted(node["properties"])
        properties[name] = info
    return {
        "required": sorted(schema.get("required", [])),
        "extra_forbidden": schema.get("additionalProperties") is False,
        "properties": properties,
    }


def operations() -> dict[str, Any]:
    """Every operation in the OpenAPI document: query keys, body schema and response codes."""
    spec = json.loads((BACKEND / "docs" / "openapi.json").read_text())
    out: dict[str, Any] = {}
    for path, item in spec["paths"].items():
        for method, op in item.items():
            if method not in ("get", "post", "put", "patch", "delete"):
                continue
            query = {}
            for param in op.get("parameters", []):
                if param["in"] == "query":
                    schema = param.get("schema", {})
                    members = [m for m in schema.get("anyOf", [schema]) if m.get("type") != "null"]
                    base = members[0] if members else {}
                    query[param["name"]] = {
                        key: base[key] for key in ("maximum", "minimum") if key in base
                    }
            body = (
                op.get("requestBody", {}).get("content", {}).get("application/json", {}).get("schema")
            )
            out[f"{method.upper()} {path}"] = {
                "query": query,
                "body": body.get("$ref", "").split("/")[-1] if body else None,
                "responses": sorted(code for code in op["responses"] if code.isdigit()),
            }
    return dict(sorted(out.items()))


# Response schemas the app parses. `schemas.json` records the keys each one requires and which keys
# may be null, so the contract tests can check that the app's models require them too.
RESPONSE_SCHEMAS = [
    "Agent",
    "AIConversationSummary",
    "Amenity",
    "AppVersionCheckResponse",
    "BugReportResponse",
    "ConversationMessageOut",
    "DeviceRegistration",
    "IdentifierStatusResponse",
    "ListingPreferences",
    "NotificationSettings",
    "PagePublicResponse",
    "PrivacySettings",
    "Property",
    "PropertyAgent",
    "PropertyAmenityResponse",
    "PropertyDetail",
    "PropertyImage",
    "PublicUserRef",
    "SelfUser",
    "SwipeOut",
    "UserLocation",
    "UserPreferences",
    "Visit",
    "VisitAgentInfo",
]


def schemas() -> dict[str, Any]:
    """Required keys, nullable keys and all keys of each response schema in the OpenAPI document."""
    spec = json.loads((BACKEND / "docs" / "openapi.json").read_text())
    components = spec["components"]["schemas"]

    def nullable(node: dict[str, Any]) -> bool:
        return any(member.get("type") == "null" for member in node.get("anyOf", []))

    def is_enum(node: dict[str, Any]) -> bool:
        for member in node.get("anyOf", [node]):
            if "$ref" in member:
                member = components[member["$ref"].split("/")[-1]]
            if "enum" in member:
                return True
        return False

    out: dict[str, Any] = {}
    for name in RESPONSE_SCHEMAS:
        schema = components[name]
        properties = schema.get("properties", {})
        out[name] = {
            "required": sorted(schema.get("required", [])),
            "nullable": sorted(key for key, node in properties.items() if nullable(node)),
            # An unknown or missing enum value reads as null, so these keys never reject null.
            "enums": sorted(key for key, node in properties.items() if is_enum(node)),
            "properties": sorted(properties),
        }
    return out


def push_data(*, route: str | None, type_key: str, data: dict[str, Any] | None = None):
    """The FCM `data` map for one ghar push, built by the backend's own functions."""
    payload = _augment_data_with_meta(
        data, type_key=type_key, channel=NotificationChannel.PUSH, priority="high"
    )
    message = build_message(
        token="fcm-token", title="Title", body="Body", data=payload, route=route, type_key=type_key
    )
    return message["message"]["data"]


def fixtures():
    widget = WidgetFrame(
        data=make_widget_data(
            "PropertySearchWidget",
            {"items": [prop(1)], "limit": 5, "has_more": False, "next_cursor": None, "total": None},
        )
    )
    frames = [
        ConversationInfoFrame(data=ConversationInfoData(conversation_id=42)),
        TextChunkFrame(data=TextChunkData(text="Here are ")),
        ToolCallStartFrame(data=ToolCallStartData(call_id="call_a", tool="discovery_search")),
        ToolCallStartFrame(data=ToolCallStartData(call_id="call_b", tool="discovery_property_get")),
        ToolCallEndFrame(
            data=ToolCallEndData(call_id="call_a", tool="discovery_search", success=True)
        ),
        ToolCallEndFrame(
            data=ToolCallEndData(call_id="call_b", tool="discovery_property_get", success=False)
        ),
        widget,
        TextChunkFrame(data=TextChunkData(text="three options.")),
        DoneFrame(data=DoneData(response_text="Here are three options.")),
    ]
    error_frame = ErrorFrame(
        data=ErrorData(
            code="AGENT_ERROR", message="The assistant could not finish this reply. Try again."
        )
    )
    return {
        "properties": {
            "list_page": page(
                Property,
                [prop(1), rent_prop(2), stay_prop(3), pg_prop(4)],
                next_cursor="eyJrIjpbInByaWNlIiwxXSwiZiI6ImFiYzEyMzQ1Njc4OSJ9",
                limit=20,
            ),
            "detail": dump(
                PropertyDetail,
                prop(
                    1,
                    agent={
                        "id": 4,
                        "name": "Ravi Kumar",
                        "contact_number": "+919811111111",
                        "avatar_url": "https://cdn.example.com/a/4.jpg",
                    },
                    owner_contact="+919811111111",
                    user_has_scheduled_visit=True,
                    user_scheduled_visit_count=1,
                    user_next_visit_date="2026-10-04T05:30:00Z",
                    listing_preferences={"gender_preference": "any", "sharing_type": "entire_flat"},
                ),
            ),
            "detail_rent": dump(PropertyDetail, rent_prop(2, agent=None)),
            "detail_short_stay": dump(PropertyDetail, stay_prop(3, agent=None)),
            "detail_pg": dump(PropertyDetail, pg_prop(4, agent=None)),
        },
        "swipes": {
            "history_page": page(Property, [prop(3, liked=True)], limit=50),
            "recorded": dump(SwipeOut, {"id": 301, "property_id": 3, "is_liked": True}),
            "updated": dump(SwipeOut, {"id": 301, "property_id": 3, "is_liked": False}),
        },
        "visits": {
            "list_page": page(
                Visit,
                [
                    visit(
                        90,
                        counterparty_user_id=61,
                        counterparty_user=public_user(61, "Karan Mehta", None),
                        visit_context="flatmate_meet",
                        conversation_id=8,
                        match_id=9,
                    ),
                    visit(91, status="completed", scheduled_date="2026-09-01T09:00:00Z",
                          agents=None, agent_id=None, property=None, time_slot_label=None),
                ],
                limit=25,
            ),
            "created": dump(Visit, visit(92)),
            "cancelled": dump(
                Visit, visit(92, status="cancelled", cancellation_reason="Plans changed")
            ),
            "rescheduled": dump(
                Visit,
                visit(
                    92,
                    status="reschedule_suggested",
                    scheduled_date="2026-10-06T09:00:00Z",
                    rescheduled_from="2026-10-04T05:30:00Z",
                    cancellation_reason="Traffic",
                ),
            ),
        },
        "agents": {
            "assigned": dump(
                Agent,
                {
                    "id": 4,
                    "name": "Ravi Kumar",
                    "agent_type": "general",
                    "experience_level": "intermediate",
                    "is_active": True,
                    "is_available": True,
                    "total_users_assigned": 12,
                    "user_satisfaction_rating": 4.6,
                    "created_at": NOW,
                    "contact_number": "+919811111111",
                },
            ),
        },
        "users": {
            "profile": dump(SelfUser, self_user()),
            "profile_minimal": dump(
                SelfUser,
                self_user(
                    email=None, phone=None, full_name=None, date_of_birth=None,
                    profile_image_url=None, agent_id=None, preferences=None,
                    notification_settings=None, privacy_settings=None, last_auth_method=None,
                ),
            ),
            "notification_settings": dump(
                NotificationSettings, {"push_notifications": False, "promotional_emails": True}
            ),
            "privacy_settings": dump(PrivacySettings, {"profile_visibility": "private"}),
            "preferences": dump(
                UserPreferences, {"purpose": "buy", "budget_min": 2_500_000.5, "location_preference": ["Gurugram"]}
            ),
            "location": dump(UserLocation, {"current_latitude": 28.42, "current_longitude": 77.08}),
        },
        "support": {
            "bug": dump(
                BugReportResponse,
                {
                    "id": 3, "user_id": 50, "source": "mobile", "bug_type": "ui_bug",
                    "severity": "low", "status": "open", "title": "Map pin overlaps",
                    "description": "On 320 px width.", "steps_to_reproduce": None,
                    "expected_behavior": None, "actual_behavior": None,
                    "device_info": {"platform": "ios"}, "app_version": "3.2.0", "media_urls": None,
                    "tags": ["map"], "assigned_to": None, "resolution": None,
                    "resolved_at": None, "created_at": NOW, "updated_at": None,
                },
            ),
        },
        "pages": {
            "privacy": dump(
                PagePublicResponse,
                {
                    "unique_name": "privacy-policy", "title": "Privacy policy",
                    "content": "# Privacy\n\nWe keep…", "format": "markdown",
                    "custom_config": None, "view_count": 40, "updated_at": NOW,
                },
            ),
            "html": dump(
                PagePublicResponse,
                {
                    "unique_name": "terms-of-service", "title": "Terms of service",
                    "content": "<h1>Terms</h1>", "format": "html", "custom_config": None,
                    "view_count": 12, "updated_at": None,
                },
            ),
        },
        "auth": {
            "identifier_status": dump(
                IdentifierStatusResponse,
                {"exists": True, "verified": True, "has_password": False, "channel": "phone",
                 "next_step": "otp"},
            ),
            "identifier_status_email": dump(
                IdentifierStatusResponse,
                {"exists": True, "verified": True, "has_password": True, "channel": "email",
                 "next_step": "password"},
            ),
        },
        "assistant": {
            # The tool names the backend registers: each one has a progress line in the chat.
            "tool_names": json.loads(
                (BACKEND / "chatgpt-widgets" / "src" / "generated" / "tool-names.json").read_text()
            ),
            "conversations_page": page(
                AIConversationSummary,
                [{"id": 42, "title": "2BHK under 30k", "created_at": NOW, "updated_at": NOW,
                  "message_count": 6}],
                next_cursor="eyJrIjpbIjIwMjYtMDktMzAiLDQyXSwiZiI6ImFiYyJ9",
            ),
            "messages_page": page(
                ConversationMessageOut,
                [
                    {"id": 311, "role": "user", "content": "2BHK in Gurgaon under 30k",
                     "created_at": NOW},
                    {"id": 312, "role": "widget", "content": None,
                     "tool_name": "PropertySearchWidget",
                     "tool_result": {"items": [prop(1)], "limit": 5, "has_more": False,
                                     "next_cursor": None, "total": None},
                     "created_at": NOW},
                    {"id": 313, "role": "assistant", "content": "Here are three options.",
                     "created_at": NOW},
                ],
                next_cursor="eyJrIjpbIjIwMjYtMDktMzAiLDMxMV19",
                limit=30,
            ),
            "frames": [
                {"event": f.event, "data": json.loads(f.data.model_dump_json(exclude_unset=True))}
                for f in frames
            ],
            "error_frame": {
                "event": error_frame.event,
                "data": json.loads(error_frame.data.model_dump_json()),
            },
            # The exact bytes the backend writes for the same frames.
            "stream": "".join(sse_frame(f) for f in frames),
            "error_stream": sse_frame(error_frame),
        },
        "notifications": {
            "registration": dump(
                DeviceRegistration,
                {"platform": "ios", "app_key": "ghar", "app_version": "3.2.0+41",
                 "locale": "en_IN", "last_seen": NOW},
            ),
            "push_property": push_data(
                route="/property/12", type_key="property_recommendation", data={"property_id": 12}
            ),
            "push_visits": push_data(route="/visits", type_key="visit_reminder"),
            "push_type_only": push_data(route=None, type_key="visit_reminder"),
            "push_unknown_route": push_data(route="/chats/5", type_key="flatmate_new_message"),
        },
        "amenities": {
            "page": page(
                Amenity,
                [
                    {"id": 11, "title": "Swimming Pool", "icon": "pool", "category": "recreation",
                     "created_at": NOW, "updated_at": NOW},
                    {"id": 12, "title": "Power Backup", "icon": "battery", "category": "utilities",
                     "created_at": NOW, "updated_at": NOW},
                ],
                next_cursor="eyJrIjpbIlBvd2VyIEJhY2t1cCIsMTJdLCJmIjoiYWJjIn0",
                limit=100,
            ),
        },
        "versions": {
            "check_response": dump(
                AppVersionCheckResponse,
                {"update_available": True, "is_mandatory": False, "latest_version": "3.3.0",
                 "download_url": "https://example.com/app", "release_notes": "Fixes",
                 "min_supported_version": "3.0.0"},
            ),
        },
        "errors": {
            "unauthorized": dump(
                ErrorEnvelope, error_body("TOKEN_INVALID", "The token is not valid.")
            ),
            "inactive": dump(
                ErrorEnvelope, error_body("USER_INACTIVE", "This account is deactivated.")
            ),
            "forbidden": dump(ErrorEnvelope, error_body("USER_ACCESS_DENIED", "Not allowed.")),
            "not_found": dump(ErrorEnvelope, error_body("PAGE_NOT_FOUND", "Page not found.")),
            "conflict": dump(
                ErrorEnvelope, error_body("VISIT_CONFLICT", "You already have a visit then.")
            ),
            "rate_limited": dump(
                ErrorEnvelope, error_body("RATE_LIMIT_EXCEEDED", "Too many requests.")
            ),
            "server": dump(ErrorEnvelope, error_body("INTERNAL_ERROR", "An unexpected error occurred")),
            "validation": dump(
                ValidationErrorEnvelope,
                error_body(
                    "VALIDATION_ERROR",
                    "Request validation failed",
                    validation_details(
                        [
                            {"loc": ("body", "date_of_birth"), "msg": "Must be at least 18 years old",
                             "type": "AGE_RANGE"},
                            {"loc": ("body", "full_name"), "msg": "Field required", "type": "missing"},
                            {"loc": ("query", "limit"), "msg": "Input should be less than or equal to 100",
                             "type": "less_than_equal"},
                        ]
                    ),
                ),
            ),
            "validation_no_fields": dump(
                ValidationErrorEnvelope,
                error_body("INVALID_CURSOR", "Cursor does not match", {"fields": []}),
            ),
        },
        # Request bodies the app sends.
        "requests": {
            name: flatten_request(model)
            for name, model in {
                "DeviceRegisterIn": DeviceRegisterIn,
                "DeviceUnregisterIn": DeviceUnregisterIn,
                "VisitCreate": VisitCreate,
                "VisitCancel": VisitCancel,
                "VisitReschedule": VisitReschedule,
                "SwipeCreate": SwipeCreate,
                "BugReportCreate": BugReportCreate,
                "UserUpdate": UserUpdate,
                "UserPreferencesPatch": UserPreferencesPatch,
                "NotificationSettingsWrite": NotificationSettingsWrite,
                "LocationUpdate": LocationUpdate,
                "AgentChatRequest": AgentChatRequest,
                "AppVersionCheckRequest": AppVersionCheckRequest,
                "IdentifierStatusRequest": IdentifierStatusRequest,
                "LastMethodRequest": LastMethodRequest,
                "DeleteAccountRequest": DeleteAccountRequest,
            }.items()
        },
        "operations": operations(),
        "schemas": schemas(),
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for group, data in fixtures().items():
        path = OUT / f"{group}.json"
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False, sort_keys=True) + "\n")
        print(f"wrote {path.relative_to(APP)}")


if __name__ == "__main__":
    main()
