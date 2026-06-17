import pyodbc
from database import get_connection

def add_session_token_column():
    db = get_connection()
    cursor = db.cursor()
    try:
        # Kiá»ƒm tra xem cá»™t session_token Ä‘Ã£ tá»“n táº¡i chÆ°a
        cursor.execute("""
            IF NOT EXISTS (
                SELECT * FROM sys.columns 
                WHERE Name = N'session_token' AND Object_ID = Object_ID(N'dbo.users')
            )
            BEGIN
                ALTER TABLE dbo.users ADD session_token NVARCHAR(255) NULL;
                PRINT 'Added session_token column to dbo.users';
            END
            ELSE
            BEGIN
                PRINT 'Column session_token already exists';
            END
        """)
        db.commit()
        print("Cáº­p nháº­t schema thÃ nh cÃ´ng.")
    except Exception as e:
        db.rollback()
        print(f"Lá»—i khi cáº­p nháº­t schema: {e}")
    finally:
        cursor.close()
        db.close()

if __name__ == "__main__":
    add_session_token_column()
