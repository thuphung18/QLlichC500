import os

def fix_mojibake(text):
    try:
        # It's UTF-8 interpreted as windows-1252 and saved as UTF-8
        new_text = text.encode('windows-1252').decode('utf-8')
        return new_text, new_text != text
    except Exception as e:
        return text, False

def process_directory(directory):
    changed_files = 0
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".dart"):
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    fixed_content, changed = fix_mojibake(content)
                    if changed:
                        with open(file_path, 'w', encoding='utf-8') as f:
                            f.write(fixed_content)
                        print(f"Fixed: {file_path}")
                        changed_files += 1
                except Exception as e:
                    print(f"Error processing {file_path}: {e}")
    print(f"Total files fixed: {changed_files}")

if __name__ == '__main__':
    process_directory(r'e:\Cong_Viec_Chuyen_mon\Flutter_project\QlLich\app_mobile_lich-main\lib')
