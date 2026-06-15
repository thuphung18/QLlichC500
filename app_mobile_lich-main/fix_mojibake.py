import os
import sys

def fix_mojibake(text):
    try:
        # If it was UTF-8 bytes decoded as latin-1
        return text.encode('latin-1').decode('utf-8')
    except:
        return text

with open("test_mojibake.py", "w", encoding="utf-8") as f:
    f.write("print('OK')")

test_string = "quáº£n trá»‹ viÃªn"
print("Original:", test_string)
print("Fixed:", fix_mojibake(test_string))
