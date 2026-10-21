#!/usr/bin/env python3
"""Loopback-only fixtures for native UI verification. No external services or writes.

Run with Python 3. Configure both API_BASE_URL and SUPABASE_URL as
http://127.0.0.1:54321 and disable Firebase in an isolated debug app copy.
The fake account is phone 9999999999 (or fixture@example.invalid), password
Fixture123!. Mutations affect only this process memory. This is not an
OAuth, production authentication, delivery, or backend contract test.
"""
import base64
import json
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

ROOT = Path(__file__).resolve().parents[2]
NOW = datetime.now(timezone.utc)
STAMP = NOW.isoformat()
USER_ID = '00000000-0000-4000-8000-000000000001'
USER = {'id': USER_ID, 'aud': 'authenticated', 'role': 'authenticated',
        'email': 'fixture@example.invalid', 'phone': '919999999999',
        'created_at': STAMP, 'email_confirmed_at': STAMP, 'phone_confirmed_at': STAMP,
        'app_metadata': {'provider': 'email', 'providers': ['email']},
        'user_metadata': {'has_password': True}, 'identities': []}
PROFILE = {'id': 1, 'supabase_user_id': USER_ID, 'email': USER['email'],
           'full_name': 'Fixture User', 'phone': USER['phone'],
           'date_of_birth': '1990-01-01', 'is_active': True, 'is_verified': True,
           'created_at': STAMP, 'agent_id': 1, 'preferences': {'purpose': 'buy'}}
SWIPES = {7: True, 8: False}
AGENT = {'id': 1, 'name': 'Fixture Agent', 'agent_type': 'general',
         'experience_level': 'expert', 'contact_number': '+919999999997',
         'languages': ['English', 'Hindi'], 'is_active': True, 'is_available': True,
         'created_at': STAMP}
VISITS = {1: {'id': 1, 'property_id': 7, 'user_id': 1, 'agent_id': 1,
              'scheduled_date': (NOW + timedelta(days=2)).isoformat(),
              'status': 'confirmed', 'created_at': STAMP}}


def prop(i):
    return {'id': i, 'title': f'Garden Court Residence {i}',
            'base_price': 8500000 + i * 100000, 'property_type': 'apartment',
            'purpose': 'buy', 'bedrooms': 3, 'bathrooms': 2, 'area_sqft': 1450,
            'city': 'Gurugram', 'state': 'Haryana', 'locality': 'Sector 57',
            'full_address': 'Sector 57, Gurugram, Haryana', 'is_active': True,
            'latitude': 28.43 + i / 1000, 'longitude': 77.07 + i / 1000,
            'main_image_url': 'http://127.0.0.1:54321/fixture-image.png',
            'virtual_tour_url': 'http://127.0.0.1:54321/fixture-tour',
            'description': 'Local fixture for native layout and recovery checks.',
            'liked': SWIPES.get(i, False), 'view_count': 24, 'like_count': 8,
            'interest_count': 3, 'created_at': STAMP}


def envelope(items):
    return {'items': items, 'has_more': False, 'next_cursor': None, 'limit': 20}


def visit_payload(visit):
    return {**visit, 'property': prop(visit['property_id']),
            'agents': {'id': AGENT['id'], 'name': AGENT['name'],
                       'phone': AGENT['contact_number']},
            'property_title': prop(visit['property_id'])['title'],
            'agent_name': AGENT['name']}


def fixture_identifier(value):
    if not isinstance(value, str):
        return False
    if '@' in value:
        return value.strip().lower() == USER['email']
    return ''.join(c for c in value if c.isdigit()) in ('9999999999', USER['phone'])


def token():
    def encode(data):
        return base64.urlsafe_b64encode(json.dumps(data).encode()).decode().rstrip('=')
    expires_at = int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp())
    jwt = '.'.join([encode({'alg': 'none', 'typ': 'JWT'}),
                    encode({'sub': USER_ID, 'aud': 'authenticated',
                            'exp': expires_at}),
                    'local-fixture-signature'])
    return {'access_token': jwt, 'refresh_token': 'local-fixture-refresh',
            'token_type': 'bearer', 'expires_in': 3600, 'expires_at': expires_at, 'user': USER}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # Do not record request bodies, headers, or query values.

    def send(self, data, status=200, content_type='application/json'):
        raw = data if isinstance(data, bytes) else json.dumps(data).encode()
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(raw)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(raw)

    def handle_request(self):
        url = urlsplit(self.path)
        path = url.path.rstrip('/')
        query = parse_qs(url.query)
        length = int(self.headers.get('Content-Length', 0))
        try:
            body = json.loads(self.rfile.read(length)) if length else {}
            if not isinstance(body, dict):
                raise ValueError()
        except (ValueError, UnicodeDecodeError):
            return self.send({'message': 'Expected a JSON object'}, 400)
        route = path.removeprefix('/api/v1')
        if path == '/fixture-image.png':
            image = ROOT / 'assets/images/onboarding_slide_1.jpg'
            if not image.exists():
                image = ROOT / 'assets/icons/splash_logo.png'
            return self.send(image.read_bytes(), content_type='image/jpeg' if image.suffix == '.jpg' else 'image/png')
        if path == '/fixture-tour':
            return self.send(b'<html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body style="background:white;color:#152720;font:24px sans-serif"><h1>Local tour fixture</h1><p>Native WebView rendered this page.</p></body></html>', content_type='text/html')
        if path == '/auth/v1/token':
            grant = query.get('grant_type', ['password'])[0]
            valid = (
                grant == 'password' and body.get('password') == 'Fixture123!'
                and fixture_identifier(body.get('phone') or body.get('email'))
            ) or (
                grant == 'refresh_token' and body.get('refresh_token') == 'local-fixture-refresh'
            )
            if not valid:
                return self.send({'msg': 'Invalid login credentials',
                                  'error_code': 'invalid_credentials'}, 400)
            return self.send(token())
        if path == '/auth/v1/user':
            return self.send(USER)
        if path == '/auth/v1/logout':
            return self.send({})
        if route == '/auth/identifier-status':
            identifier = body.get('identifier', '')
            exists = fixture_identifier(identifier)
            return self.send({'exists': exists, 'verified': exists, 'has_password': exists,
                              'channel': 'email' if '@' in str(identifier) else 'phone',
                              'next_step': 'password' if exists else 'otp'})
        if route == '/auth/last-method':
            return self.send({'message': 'Recorded locally'})
        if route == '/users/profile':
            if self.command == 'PUT':
                PROFILE.update(body)
            return self.send(PROFILE)
        if route == '/users/preferences':
            if self.command == 'PUT':
                PROFILE['preferences'].update(body)
            return self.send(PROFILE)
        if route == '/users/location':
            if self.command == 'PUT':
                PROFILE['current_latitude'] = body.get('latitude')
                PROFILE['current_longitude'] = body.get('longitude')
            return self.send(PROFILE)
        if route == '/properties':
            ids = range(1, 13)
            if 'ids' in query:
                ids = [int(i) for i in query['ids']]
            if query.get('exclude_swiped') == ['true']:
                ids = [i for i in ids if i not in SWIPES]
            return self.send(envelope([prop(i) for i in ids]))
        if route.startswith('/properties/') and route.split('/')[-1].isdigit():
            return self.send(prop(int(route.split('/')[-1])))
        if route == '/swipes':
            if self.command == 'POST':
                SWIPES[int(body['property_id'])] = bool(body['is_liked'])
                return self.send({'success': True, 'message': 'Stored in fixture memory'})
            liked = query.get('is_liked', ['true'])[0] == 'true'
            return self.send(envelope([prop(i) for i, value in list(SWIPES.items()) if value == liked]))
        if route == '/visits':
            if self.command == 'POST':
                property_id, scheduled_date = body.get('property_id'), body.get('scheduled_date')
                try:
                    if type(property_id) is not int or property_id <= 0:
                        raise ValueError()
                    datetime.fromisoformat(str(scheduled_date).replace('Z', '+00:00'))
                except ValueError:
                    return self.send({'message': 'A property and scheduled date are required'}, 422)
                visit_id = max(VISITS, default=0) + 1
                visit = {'id': visit_id, 'property_id': property_id, 'user_id': PROFILE['id'],
                         'agent_id': AGENT['id'], 'scheduled_date': scheduled_date,
                         'special_requirements': body.get('special_requirements', ''),
                         'status': 'requested', 'created_at': datetime.now(timezone.utc).isoformat()}
                VISITS[visit_id] = visit
                return self.send(visit_payload(visit), 201)
            return self.send(envelope([visit_payload(v) for v in list(VISITS.values())]))
        if route.startswith('/visits/'):
            parts = route.strip('/').split('/')
            visit = VISITS.get(int(parts[1])) if parts[1].isdigit() else None
            if visit is None:
                return self.send({'message': 'Visit not found'}, 404)
            if len(parts) == 2 and self.command == 'GET':
                return self.send(visit_payload(visit))
            if self.command == 'POST' and parts[-1] == 'cancel':
                visit.update(status='cancelled', cancellation_reason=body.get('reason', ''))
                return self.send({'success': True})
            if self.command == 'POST' and parts[-1] == 'reschedule':
                new_date = body.get('new_date')
                try:
                    datetime.fromisoformat(str(new_date).replace('Z', '+00:00'))
                except ValueError:
                    return self.send({'message': 'A new date is required'}, 422)
                visit.update(status='reschedule_suggested', rescheduled_from=visit['scheduled_date'],
                             scheduled_date=new_date)
                return self.send({'success': True})
        if route == '/agents/assigned':
            return self.send(AGENT)
        if route == '/agent/conversations':
            return self.send(envelope([]))
        if route.startswith('/pages/'):
            return self.send({'title': 'Local fixture', 'content': '<h1>Local support page</h1><p>Native navigation check.</p>'})
        return self.send({'message': 'No fixture for this operation'}, 404)

    do_GET = handle_request
    do_POST = handle_request
    do_PUT = handle_request


if __name__ == '__main__':
    print('Native fixture server: http://127.0.0.1:54321 (memory only)', flush=True)
    ThreadingHTTPServer(('127.0.0.1', 54321), Handler).serve_forever()
