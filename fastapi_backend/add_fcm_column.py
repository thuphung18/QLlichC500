import pyodbc
from database import get_db

def add_fcm_column():
    print("Connecting to database...")
    db = get_db()
    cursor = db.cursor()
    try:
        print("Checking if fcm_token column exists...")
        cursor.execute("""
            IF COL_LENGTH('dbo.users', 'fcm_token') IS NULL
            BEGIN
                ALTER TABLE dbo.users ADD fcm_token NVARCHAR(500) NULL;
                PRINT 'Column fcm_token added successfully.'
            END
            ELSE
            BEGIN
                PRINT 'Column fcm_token already exists.'
            END
        """)
        db.commit()
    except Exception as e:
        print(f"Error: {e}")
        db.rollback()
    finally:
        cursor.close()
        db.close()
        print("Done.")

if __name__ == "__main__":
    add_fcm_column()
