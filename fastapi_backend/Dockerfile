# Sử dụng Python Slim làm Base Image để tối ưu dung lượng container
FROM python:3.11-slim-bullseye

# Thiết lập thư mục làm việc trong container
WORKDIR /app

# Thiết lập múi giờ Việt Nam
ENV TZ=Asia/Ho_Chi_Minh

# Cài đặt các công cụ biên dịch và Microsoft ODBC Driver cho SQL Server (yêu cầu bởi pyodbc)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg2 \
    build-essential \
    unixodbc-dev \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
    && echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/11/prod bullseye main" > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql17 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Sao chép file requirements và cài đặt python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Sao chép toàn bộ mã nguồn của backend vào container
COPY . .

# Render tự động gán biến PORT, nếu không có mặc định là 8000
ENV PORT=8000

# Khởi chạy ứng dụng bằng uvicorn
CMD uvicorn main:app --host 0.0.0.0 --port $PORT
