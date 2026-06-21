import database

def get_sp_def():
    conn = database.get_connection()
    cursor = conn.cursor()
    
    procedures = ['sp_LoginUser', 'sp_GetSchedulesForUser', 'sp_GetScheduleDetail', 'sp_FindUserByContact']
    
    for sp in procedures:
        try:
            cursor.execute(f"SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.{sp}'))")
            row = cursor.fetchone()
            if row and row[0]:
                print(f"=== {sp} ===")
                # write definition to a text file
                with open(f"{sp}_definition.sql", "w", encoding="utf-8") as f:
                    f.write(row[0])
                print(f"Saved {sp}_definition.sql")
            else:
                print(f"Could not find definition for {sp}")
        except Exception as e:
            print(f"Error getting definition for {sp}: {e}")
            
    cursor.close()
    conn.close()

if __name__ == "__main__":
    get_sp_def()
