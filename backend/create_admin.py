
import re
import getpass

from auth import get_connection, hash_password


def create_admin():
    print("\n=== Audio2Text AI - Admin Setup ===\n")

    full_name = input("Admin full name: ").strip()
    email = input("Admin email: ").strip().lower()
    phone = input("Admin phone (optional): ").strip()

    if len(full_name) < 2:
        print("Error: Name must contain at least 2 characters.")
        return

    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
        print("Error: Invalid email address.")
        return

    password = getpass.getpass("Admin password (minimum 12 characters): ")
    confirm = getpass.getpass("Confirm password: ")

    if len(password) < 12:
        print("Error: Password must contain at least 12 characters.")
        return

    if password != confirm:
        print("Error: Passwords do not match.")
        return

    connection = get_connection()

    try:
        connection.execute("BEGIN IMMEDIATE")

        existing = connection.execute(
            "SELECT id FROM users WHERE role = 'admin' LIMIT 1"
        ).fetchone()

        if existing:
            print("An administrator already exists. Setup is locked.")
            connection.rollback()
            return

        connection.execute(
            """
            INSERT INTO users (
                full_name,
                email,
                phone,
                password_hash,
                role,
                is_active
            )
            VALUES (?, ?, ?, ?, 'admin', 1)
            """,
            (
                full_name,
                email,
                phone,
                hash_password(password),
            ),
        )

        connection.commit()
        print("\nAdmin account created successfully!")

    except Exception as error:
        connection.rollback()
        print(f"Admin creation failed: {error}")

    finally:
        connection.close()


if __name__ == "__main__":
    create_admin()
