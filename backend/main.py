
from pathlib import Path
from uuid import uuid4
from threading import Lock
import sqlite3
from auth import router as auth_router, get_current_user
from fastapi import FastAPI, UploadFile, File, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware


app = FastAPI(
    title="Audio2Text AI API",
    description="Local AI audio transcription and recording history",
    version="1.2.0"
)
app.include_router(auth_router)

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

# Local Whisper configuration
MODEL_SIZE = "base"
_whisper_model = None
_model_lock = Lock()


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


def get_whisper_model():
    global _whisper_model

    if _whisper_model is None:
        with _model_lock:
            if _whisper_model is None:
                from faster_whisper import WhisperModel

                _whisper_model = WhisperModel(
                    MODEL_SIZE,
                    device="cpu",
                    compute_type="int8"
                )

    return _whisper_model


def update_recording(file_id, status, transcription=None):
    with get_connection() as connection:
        if transcription is None:
            connection.execute(
                """
                UPDATE recordings
                SET status = ?
                WHERE file_id = ?
                """,
                (status, file_id),
            )
        else:
            connection.execute(
                """
                UPDATE recordings
                SET status = ?, transcription = ?
                WHERE file_id = ?
                """,
                (status, transcription, file_id),
            )


@app.get("/")
def home():
    return {
        "app": "Audio2Text AI",
        "status": "running",
        "version": "1.2.0"
    }


@app.get("/health")
def health():
    return {
        "status": "ok",
        "backend": "online",
        "database": DATABASE_PATH.exists(),
        "transcription_engine": "faster-whisper",
        "model": MODEL_SIZE
    }


@app.post("/upload")
async def upload_audio(
    file: UploadFile = File(...),
    user=Depends(get_current_user),
):
    filename = Path(file.filename or "audio").name
    extension = Path(filename).suffix.lower()

    if extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail="Unsupported audio format",
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
                        detail="File exceeds 50 MB limit",
                    )

                output.write(chunk)

        if total_size == 0:
            raise HTTPException(
                status_code=400,
                detail="Empty file",
            )

        with get_connection() as connection:
            connection.execute(
                """
                INSERT INTO recordings (
                    file_id,
                    filename,
                    format,
                    size_bytes,
                    status,
                    user_id
                )
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    file_id,
                    filename[:255],
                    extension.replace(".", ""),
                    total_size,
                    "pending",
                    user["id"],
                ),
            )

        return {
            "success": True,
            "message": "File uploaded successfully",
            "file_id": file_id,
            "filename": filename,
            "size_bytes": total_size,
            "status": "pending",
        }

    except HTTPException:
        saved_path.unlink(missing_ok=True)
        raise

    except Exception:
        saved_path.unlink(missing_ok=True)
        raise HTTPException(
            status_code=500,
            detail="Upload failed",
        )

    finally:
        await file.close()


@app.post("/transcribe/{file_id}")
def transcribe_audio(
    file_id: str,
    user=Depends(get_current_user),
):
    with get_connection() as connection:
        recording = connection.execute(
            """
            SELECT file_id, format, status, user_id
            FROM recordings
            WHERE file_id = ?
            """,
            (file_id,),
        ).fetchone()

    if recording is None:
        raise HTTPException(status_code=404, detail="Recording not found")

    if user["role"] != "admin" and recording["user_id"] != user["id"]:
        raise HTTPException(status_code=404, detail="Recording not found")

    if recording["status"] == "processing":
        raise HTTPException(status_code=409, detail="Already processing")

    extension = "." + recording["format"].lower()
    audio_path = UPLOAD_DIR / f"{file_id}{extension}"

    if not audio_path.is_file():
        raise HTTPException(status_code=404, detail="Audio file not found")

    update_recording(file_id, "processing")

    try:
        model = get_whisper_model()

        segments, info = model.transcribe(
            str(audio_path),
            beam_size=1,
        )

        transcription_parts = []
        segments_count = 0

        for segment in segments:
            text = segment.text.strip()

            if text:
                transcription_parts.append(text)
                segments_count += 1

        transcription = " ".join(transcription_parts)

        if not transcription:
            raise ValueError("No speech detected")

        update_recording(
            file_id,
            "completed",
            transcription,
        )

        return {
            "success": True,
            "file_id": file_id,
            "status": "completed",
            "language": info.language,
            "language_probability": info.language_probability,
            "segments_count": segments_count,
            "transcription": transcription,
        }

    except Exception:
        update_recording(file_id, "failed")
        raise HTTPException(
            status_code=500,
            detail="Transcription failed",
        )

@app.get("/history")
def get_history(user=Depends(get_current_user)):
    with get_connection() as connection:

        if user["role"] == "admin":
            rows = connection.execute(
                """
                SELECT
                    id,
                    file_id,
                    filename,
                    format,
                    size_bytes,
                    status,
                    transcription,
                    estimated_cost_mad,
                    created_at
                FROM recordings
                ORDER BY id DESC
                """
            ).fetchall()

        else:
            rows = connection.execute(
                """
                SELECT
                    id,
                    file_id,
                    filename,
                    format,
                    size_bytes,
                    status,
                    transcription,
                    estimated_cost_mad,
                    created_at
                FROM recordings
                WHERE user_id = ?
                ORDER BY id DESC
                """,
                (user["id"],),
            ).fetchall()

    return {
        "success": True,
        "total": len(rows),
        "recordings": [dict(row) for row in rows],
    }