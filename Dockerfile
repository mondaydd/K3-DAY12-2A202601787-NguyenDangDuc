# ═══════════════════════════════════════════════════════════════════
# CP2 — Multi-stage Dockerfile (production-ready)
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder ────────────────────────────────────────────────
# Stage này chỉ dùng để cài thư viện Python. Nó có thể nặng vì sẽ bị
# bỏ đi sau khi copy kết quả sang stage runtime.
FROM python:3.11-slim AS builder

WORKDIR /app

# Copy requirements.txt TRƯỚC, rồi mới pip install.
# Lý do: Docker cache theo từng layer. Nếu requirements.txt không đổi,
# Docker dùng cache layer pip install → build nhanh hơn nhiều.
# Nếu COPY . . trước thì mỗi lần sửa 1 dòng code = cài lại toàn bộ thư viện.
COPY requirements.txt .

# Cài vào /install thay vì /usr/local mặc định → dễ copy sang stage sau
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: runtime ────────────────────────────────────────────────
# Stage cuối — đây là image thật được dùng trên production.
# Không có compiler, không có cache pip → nhỏ gọn.
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy kết quả pip install từ stage builder sang
# (chỉ lấy thư viện đã cài, không mang theo compiler)
COPY --from=builder /install /usr/local

# Copy source code (làm SAU khi cài thư viện để tận dụng cache Docker)
COPY app ./app
COPY utils ./utils

# Tạo user thường (không phải root) — bảo mật:
# Nếu ai thoát được khỏi app, họ chỉ là appuser, không phải root trên host.
RUN useradd --create-home --uid 10001 appuser
USER appuser

# Kiểm tra process còn sống không (liveness probe của Docker)
# Gọi /health mỗi 30 giây, timeout 5s, thử lại 3 lần trước khi báo unhealthy
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health').read()" || exit 1

# Đọc PORT từ biến môi trường (Railway/Render tự gán cổng, không cố định 8000)
# ${PORT:-8000} nghĩa là: dùng $PORT nếu có, không thì dùng 8000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
