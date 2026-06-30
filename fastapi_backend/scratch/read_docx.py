import docx
import sys
sys.stdout.reconfigure(encoding='utf-8')

def read_docx(file_path):
    doc = docx.Document(file_path)
    for para in doc.paragraphs:
        if para.text.strip():
            print(para.text)

if __name__ == '__main__':
    read_docx(r'e:\Cong_Viec_Chuyen_mon\Flutter_project\QlLich\Huong_dan_deploy_Render.docx')
