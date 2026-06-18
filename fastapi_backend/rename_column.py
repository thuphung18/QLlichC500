from database import get_connection

def rename_column():
    conn = get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("EXEC sp_rename 'dbo.users.session_token', 'refresh_token', 'COLUMN';")
        conn.commit()
        print("Column renamed successfully.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        conn.close()

if __name__ == '__main__':
    rename_column()
