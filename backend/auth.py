
import hashlib
import secrets
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field


BASE_DIR = Path(__file__).resolve().parent
DATABASE_PATH = BASE_DIR.parent / "database" / "audio2text.db"

router = APIRouter(prefix="/auth", tags=["Authentication"])
security = HTTPBearer(auto_error=False)

SESSION_DAYS = 7
PBKDF2_ITERATIONS = 310_000


def get_connection():
    connection = sqlite3.connect(DATABASE_PATH)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    return connection


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    derived = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        PBKDF2_ITERATIONS,
    ).hex()

    return f"pbkdf2_sha256${PBKDF2_ITERATIONS}${salt}${derived}"


def verify_password(password: str, stored_hash: str) -> bool:
    try:
        algorithm, iterations, salt, expected = stored_hash.split("$")

        if algorithm != "pbkdf2_sha256":
            return False

        actual = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            salt.encode("utf-8"),
            int(iterations),
        ).hex()

        return secrets.compare_digest(actual, expected)
    except (ValueError, TypeError):
        return False


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


class RegisterRequest(BaseModel):
    full_name: str = Field(min_length=2, max_length=100)
    email: str = Field(min_length=5, max_length=150)
    phone: str = Field(default="", max_length=30)
    password: str = Field(min_length=8, max_length=128)


class LoginRequest(BaseModel):
    email: str = Field(min_length=5, max_length=150)
    password: str = Field(min_length=8, max_length=128)


def create_session(user_id: int):
    token = secrets.token_urlsafe(32)
    token_hash = hash_token(token)

    expires_at = (
        datetime.now(timezone.utc) + timedelta(days=SESSION_DAYS)
    ).isoformat()

    with get_connection() as connection:
        connection.execute(
            """
            INSERT INTO sessions (user_id, token_hash, expires_at)
            VALUES (?, ?, ?)
            """,
            (user_id, token_hash, expires_at),
        )

    return token, expires_at


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
):
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=401,
            detail="Authentication required",
        )

    token_hash = hash_token(credentials.credentials)

    with get_connection() as connection:
        row = connection.execute(
            """
            SELECT
                users.id,
                users.full_name,
                users.email,
                users.phone,
                users.role,
                users.is_active,
                sessions.expires_at
            FROM sessions
            JOIN users ON users.id = sessions.user_id
            WHERE sessions.token_hash = ?
            """,
            (token_hash,),
        ).fetchone()

        if row is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid session",
            )

        expires_at = datetime.fromisoformat(row["expires_at"])

        if expires_at <= datetime.now(timezone.utc):
            connection.execute(
                "DELETE FROM sessions WHERE token_hash = ?",
                (token_hash,),
            )
            raise HTTPException(
                status_code=401,
                detail="Session expired",
            )

        if not row["is_active"]:
            raise HTTPException(
                status_code=403,
                detail="Account disabled",
            )

        return dict(row)


def require_admin(user=Depends(get_current_user)):
    if user["role"] != "admin":
        raise HTTPException(
            status_code=403,
            detail="Administrator access required",
        )

    return user


@router.post("/register")
def register(data: RegisterRequest):
    full_name = data.full_name.strip()
    email = data.email.strip().lower()
    phone = data.phone.strip()

    if len(full_name) < 2 or "@" not in email:
        raise HTTPException(
            status_code=400,
            detail="Please provide valid registration details",
        )

    with get_connection() as connection:
        existing = connection.execute(
            "SELECT id FROM users WHERE email = ?",
            (email,),
        ).fetchone()

        if existing:
            raise HTTPException(
                status_code=409,
                detail="Email already registered",
            )

        cursor = connection.execute(
            """
            INSERT INTO users (
                full_name, email, phone, password_hash, role
            )
            VALUES (?, ?, ?, ?, 'client')
            """,
            (
                full_name,
                email,
                phone,
                hash_password(data.password),
            ),
        )

        user_id = cursor.lastrowid

    token, expires_at = create_session(user_id)

    return {
        "success": True,
        "message": "Account created successfully",
        "access_token": token,
        "token_type": "bearer",
        "expires_at": expires_at,
        "user": {
            "id": user_id,
            "full_name": full_name,
            "email": email,
            "phone": phone,
            "role": "client",
        },
    }


@router.post("/login")
def login(data: LoginRequest):
    email = data.email.strip().lower()

    with get_connection() as connection:
        user = connection.execute(
            """
            SELECT id, full_name, email, phone, password_hash,
                   role, is_active
            FROM users
            WHERE email = ?
            """,
            (email,),
        ).fetchone()

    if user is None or not verify_password(
        data.password, user["password_hash"]
    ):
        raise HTTPException(
            status_code=401,
            detail="Incorrect email or password",
        )

    if not user["is_active"]:
        raise HTTPException(
            status_code=403,
            detail="Account disabled",
        )

    token, expires_at = create_session(user["id"])

    return {
        "success": True,
        "access_token": token,
        "token_type": "bearer",
        "expires_at": expires_at,
        "user": {
            "id": user["id"],
            "full_name": user["full_name"],
            "email": user["email"],
            "phone": user["phone"],
            "role": user["role"],
        },
    }


@router.get("/me")
def get_me(user=Depends(get_current_user)):
    return {
        "success": True,
        "user": user,
    }


@router.post("/logout")
def logout(
    credentials: HTTPAuthorizationCredentials = Depends(security),
):
    if credentials is None:
        raise HTTPException(
            status_code=401,
            detail="Authentication required",
        )

    token_hash = hash_token(credentials.credentials)

    with get_connection() as connection:
        connection.execute(
            "DELETE FROM sessions WHERE token_hash = ?",
            (token_hash,),
        )

    return {
        "success": True,
        "message": "Logged out successfully",
    }
