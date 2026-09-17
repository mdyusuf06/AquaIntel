import sqlite3
from pathlib import Path
from typing import List, Dict, Any, Optional

DB_PATH = Path("aquaintel.db")

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS surveys (
            id TEXT PRIMARY KEY,
            origin_lat REAL,
            origin_lon REAL,
            timestamp TEXT
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS detections (
            id TEXT PRIMARY KEY,
            survey_id TEXT,
            lat REAL,
            lon REAL,
            object_type TEXT,
            risk_score INTEGER,
            confidence REAL,
            impact_type TEXT,
            FOREIGN KEY(survey_id) REFERENCES surveys(id)
        )
    ''')
    conn.commit()
    conn.close()

def start_survey(survey_id: str, lat: float, lon: float, timestamp: str):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('INSERT OR REPLACE INTO surveys (id, origin_lat, origin_lon, timestamp) VALUES (?, ?, ?, ?)',
                   (survey_id, lat, lon, timestamp))
    conn.commit()
    conn.close()

def get_survey(survey_id: str) -> Optional[Dict[str, Any]]:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM surveys WHERE id = ?', (survey_id,))
    row = cursor.fetchone()
    conn.close()
    return dict(row) if row else None

def save_detection(detection_id: str, survey_id: str, lat: float, lon: float, object_type: str, risk_score: int, confidence: float, impact_type: str):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
        INSERT OR REPLACE INTO detections (id, survey_id, lat, lon, object_type, risk_score, confidence, impact_type)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', (detection_id, survey_id, lat, lon, object_type, risk_score, confidence, impact_type))
    conn.commit()
    conn.close()

def get_survey_detections(survey_id: str) -> List[Dict[str, Any]]:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM detections WHERE survey_id = ?', (survey_id,))
    rows = cursor.fetchall()
    conn.close()
    return [dict(row) for row in rows]
