import urllib.request
import urllib.error
import json

base_url = 'http://192.168.1.4:8000'

def make_request(url, payload=None):
    try:
        if payload:
            data = json.dumps(payload).encode('utf-8')
            req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})
        else:
            req = urllib.request.Request(url)
            
        with urllib.request.urlopen(req) as response:
            status = response.getcode()
            body = response.read().decode('utf-8')
            try:
                parsed = json.loads(body)
                return status, parsed
            except:
                return status, body
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8')
    except Exception as e:
        return 500, str(e)

print('--- Testing /check-api-key ---')
status, resp = make_request(f'{base_url}/check-api-key')
print(f'Status: {status}\nResponse: {resp}')

print('\n--- Testing /process-survey ---')
survey_payload = {
    'items': [
        {
            'id': 'test-1',
            'object_type': 'Ghost net',
            'clearance_m': 2.5,
            'port_distance_m': 400.0,
            'pixel_bbox': [100, 100, 200, 200],
            'confidence': 0.95,
            'base_lat': 12.34,
            'base_lon': 56.78
        }
    ]
}
status, resp = make_request(f'{base_url}/process-survey', survey_payload)
print(f'Status: {status}\nResponse: {json.dumps(resp, indent=2) if isinstance(resp, list) else resp}')

print('\n--- Testing /mission-advisor ---')
advisor_payload = {
    'detections': [
        {'type': 'Ghost net', 'risk_tier': 'Red', 'clearance_m': 2.5}
    ],
    'context': 'Testing the Groq API integration.'
}
status, resp = make_request(f'{base_url}/mission-advisor', advisor_payload)
print(f'Status: {status}\nResponse: {str(resp).encode("ascii", "ignore").decode("ascii")}')

print('\n--- Testing /export-csv ---')
status, resp = make_request(f'{base_url}/export-csv', survey_payload)
print(f'Status: {status}\nResponse Text:\n{resp}')

print('\n--- Testing /voice-intent ---')
voice_payload = {
    'transcript': 'show me all red targets'
}
status, resp = make_request(f'{base_url}/voice-intent', voice_payload)
print(f'Status: {status}\nResponse: {resp}')
