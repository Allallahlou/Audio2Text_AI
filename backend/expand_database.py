import sqlite3
from pathlib import Path

DB = Path(__file__).resolve().parent.parent / "database" / "audio2text.db"

with sqlite3.connect(DB) as conn:
    conn.execute("PRAGMA foreign_keys = ON")

    conn.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name TEXT NOT NULL,
            email TEXT NOT NULL COLLATE NOCASE UNIQUE,
            phone TEXT,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'client'
                CHECK(role IN ('client', 'admin')),
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            token_hash TEXT NOT NULL UNIQUE,
            expires_at TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS services (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            description TEXT,
            price_mad REAL NOT NULL DEFAULT 10,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            recording_file_id TEXT,
            service_code TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            amount_mad REAL NOT NULL DEFAULT 10,
            input_text TEXT,
            result_text TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT,
            FOREIGN KEY(user_id) REFERENCES users(id),
            FOREIGN KEY(recording_file_id) REFERENCES recordings(file_id),
            FOREIGN KEY(service_code) REFERENCES services(code)
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            sender_user_id INTEGER,
            sender_role TEXT NOT NULL
                CHECK(sender_role IN ('client', 'admin', 'system')),
            message TEXT NOT NULL,
            is_read INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(user_id) REFERENCES users(id),
            FOREIGN KEY(sender_user_id) REFERENCES users(id)
        )
    """)

    columns = {
        row[1] for row in conn.execute("PRAGMA table_info(recordings)")
    }

    if "user_id" not in columns:
        conn.execute("""
            ALTER TABLE recordings
            ADD COLUMN user_id INTEGER REFERENCES users(id)
        """)

    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_orders_user
        ON orders(user_id)
    """)

    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_messages_user
        ON messages(user_id)
    """)

    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_sessions_user
        ON sessions(user_id)
    """)

    services = [
        ("audio_to_text", "Audio to Text", "تحويل الصوت لى نص"),
        ("ai_summary", "AI Summary", "تلخيص المحتوى بالذكاء الاصطناعي"),
        ("translation", "Translation", "ترجمة النصوص"),
        ("subtitles", "Subtitles", "نشاء الترجمة المصاحبة"),
        ("meeting_notes", "Meeting Notes", "عداد تقارير الاجتماعات"),
        ("key_points", "Key Points", "استخراج الفكار الرئيسية"),
    ]

    conn.executemany("""
        INSERT OR IGNORE INTO services (code, name, description, price_mad)
        VALUES (?, ?, ?, 10)
    """, services)

    print("Database expansion completed successfully.")
    print("Tables:")
    for row in conn.execute("""
        SELECT name FROM sqlite_master
        WHERE type = 'table' ORDER BY name
    """):
        print("-", row[0])

    print("Services:", conn.execute(
        "SELECT COUNT(*) FROM services"
    ).fetchone()[0])
