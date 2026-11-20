
from pathlib import Path
from uuid import uuid4
import sqlite3

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="Audio2Text AI API",
    description="Audio upload and recording history",
    version="1.1.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

BASE_DIR = Path(__file__).resolve().parent
UPLOAD_DIR = BASE_DIR / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)

DATABASE_DIR = BASE_DIR.parent / "database"
DATABASE_DIR.mkdir(exist_ok=True)

DATABASE_PATH = DATABASE_DIR / "audio2text.db"

ALLOWED_EXTENSIONS = {
    ".mp3", ".wav", ".m4a", ".aac",
    ".ogg", ".opus", ".flac", ".mp4"
}

MAX_FILE_SIZE = 50 * 1024 * 1024


def get_connection():
    connection = sqlite3.connect(DATABASE_PATH)
    connection.row_factory = sqlite3.Row
    return connection


def initialize_database():
    with get_connection() as connection:
        connection.execute("""
            CREATE TABLE IF NOT EXISTS recordings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                file_id TEXT UNIQUE NOT NULL,
                filename TEXT NOT NULL,
                format TEXT NOT NULL,
                size_bytes INTEGER NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                transcription TEXT,
                estimated_cost_mad REAL DEFAULT 0,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
        """)


initialize_database()


@app.get("/")
def home():
    return {
        "app": "Audio2Text AI",
        "status": "running",
        "version": "1.1.0"
    }


@app.get("/health")
def health():
    return {
        "status": "ok",
        "backend": "online",
        "database": DATABASE_PATH.exists()
    }


@app.post("/upload")
async def upload_audio(file: UploadFile = File(...)):
    filename = Path(file.filename or "audio").name
    extension = Path(filename).suffix.lower()

    if extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail="Unsupported audio file format"
        )

    file_id = str(uuid4())
    saved_path = UPLOAD_DIR / f"{file_id}{extension}"
    total_size = 0

    try:
        with saved_path.open("wb") as output:
            while chunk := await file.read(1024 * 1024):
                total_size += len(chunk)

                if total_size > MAX_FILE_SIZE:
                    raise HTTPException(
                        status_code=413,
                        detail="File is larger than 50 MB"
                    )

                output.write(chunk)

        with get_connection() as connection:
            connection.execute("""
                INSERT INTO recordings (
                    file_id,
                    filename,
                    format,
                    size_bytes,
                    status
                )
                VALUES (?, ?, ?, ?, ?)
            """, (
                file_id,
                filename,
                extension.replace(".", ""),
                total_size,
                "pending"
            ))

    except HTTPException:
        saved_path.unlink(missing_ok=True)
        raise

    except Exception as error:
        saved_path.unlink(missing_ok=True)
        raise HTTPException(
            status_code=500,
            detail=f"Upload failed: {str(error)}"
        )

    finally:
        await file.close()

    return {
        "success": True,
        "message": "Audio uploaded and saved to database",
        "file_id": file_id,
        "filename": filename,
        "size_bytes": total_size,
        "format": extension.replace(".", ""),
        "transcription_status": "pending"
    }


@app.get("/history")
def get_history():
    with get_connection() as connection:
        rows = connection.execute("""
            SELECT
                id,
                file_id,
                filename,
                format,
                size_bytes,
                status,
                estimated_cost_mad,
                created_at
            FROM recordings
            ORDER BY id DESC
        """).fetchall()

    return {
        "success": True,
        "total": len(rows),
        "recordings": [dict(row) for row in rows]
    }
