import os
import re

def fix_mixed_mojibake(text):
    def replacer(match):
        s = match.group(0)
        try:
            # Attempt to decode the mojibake
            decoded = s.encode('windows-1252').decode('utf-8')
            return decoded
        except Exception:
            # If it fails, it's either already correct UTF-8 or contains unmappable chars
            return s

    new_text = re.sub(r'[^\x00-\x7F]+', replacer, text)
    return new_text, new_text != text

def process_directory(directory):
    changed_files = 0
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    fixed_content, changed = fix_mixed_mojibake(content)
                    if changed:
                        with open(file_path, 'w', encoding='utf-8') as f:
                            f.write(fixed_content)
                        print(f"Fixed: {file_path}")
                        changed_files += 1
                except Exception as e:
                    pass
    print(f"Total files fixed: {changed_files}")

if __name__ == '__main__':
    process_directory(r'e:\Cong_Viec_Chuyen_mon\Flutter_project\QlLich\app_mobile_lich-main\lib')
