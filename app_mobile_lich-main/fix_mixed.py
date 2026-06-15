import os
import re

def fix_mixed_mojibake(text):
    # Find all sequences of characters in \x80-\xff
    # But wait, some mojibake might include ASCII characters if they are part of a larger string?
    # No, UTF-8 multi-byte sequences ONLY contain bytes in \x80-\xff.
    # So a UTF-8 encoded non-ASCII character will ONLY produce \x80-\xff characters when decoded as windows-1252!
    # Therefore, ALL mojibake characters are in \x80-\xff.
    # Any valid UTF-8 non-ASCII character (like 'ể') is > \xff.
    # So we can safely match [\x80-\xff]{2,} and try to decode it!
    
    def replacer(match):
        s = match.group(0)
        try:
            return s.encode('windows-1252').decode('utf-8')
        except:
            return s

    new_text = re.sub(r'[\x80-\xff]{2,}', replacer, text)
    return new_text, new_text != text

def process_directory(directory):
    changed_files = 0
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".dart"):
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
                    print(f"Error processing {file_path}: {e}")
    print(f"Total files fixed: {changed_files}")

if __name__ == '__main__':
    process_directory(r'e:\Cong_Viec_Chuyen_mon\Flutter_project\QlLich\app_mobile_lich-main\lib')
