# Phiếu Phản Ánh — K3 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng câu trả lời mẫu bằng câu trả lời của bạn.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Đăng Đức  Mã học viên: 2A202601787

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Khi deploy ứng dụng lên môi trường production mà quên cài đặt biến môi trường `AGENT_API_KEY`. Nếu để giá trị mặc định `"changeme"`, app vẫn khởi động bình thường và kẻ xấu có thể quét thấy endpoint, sử dụng khóa mặc định để gọi API làm rò rỉ dữ liệu hoặc tiêu tốn ngân sách. Việc app "chết sớm" ngay lúc startup khiến lệnh deploy báo lỗi tức thì, giúp ta phát hiện và bổ sung secret ngay khi đang theo dõi màn hình deploy.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Log JSON thu được:
`{"event": "ask_completed", "level": "info", "timestamp": "2026-08-10T05:34:09.444293+00:00", "user_id": "sv01", "cost_usd": 0.0001}`

Hai việc làm được:
1. Dùng công cụ gom log (Datadog, Grafana Loki) để lọc, truy vấn và thống kê tổng chi phí `cost_usd` theo từng `user_id` trong khoảng thời gian cụ thể.
2. Thiết lập hệ thống cảnh báo tự động (alerting) khi tỷ lệ log `level: "error"` hoặc chi phí vượt mức cho phép.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~1000 MB |
| Multi-stage | 270 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần dung lượng chênh lệch (~730 MB) là các bộ công cụ biên dịch (gcc, g++, build-essential), các file header C/C++, cache của pip install và các tiện ích hệ điều hành nặng từ base image đầy đủ. Trong multi-stage build, stage builder dùng các công cụ này để biên dịch thư viện, nhưng stage runtime chỉ copy kết quả đã biên dịch sang nên loại bỏ được toàn bộ phần rác này.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

Layer cài đặt thư viện (`RUN pip install`) được dùng lại hoàn toàn từ Docker cache vì file `requirements.txt` không thay đổi. Chỉ có layer `COPY app ./app` trở đi là phải chạy lại.
Nếu đặt `COPY . .` lên trước `RUN pip install`, bất kỳ thay đổi nhỏ nào trong code cũng làm vô hiệu hóa cache từ layer `COPY`, buộc Docker phải tải và cài đặt lại toàn bộ các thư viện Python từ đầu mỗi lần build, làm chậm quá trình CI/CD.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Chuỗi sự kiện: Kẻ tấn công khai thác lỗ hổng Remote Code Execution (RCE) trong ứng dụng Python để thực thi lệnh shell. Nếu container chạy bằng root (UID 0), tiến trình độc hại có quyền root trong container. Kết hợp với một lỗ hổng thoát container (container escape vulnerability), kẻ tấn công chiếm được quyền điều khiển máy host với đúng quyền UID 0 (root máy host).
Lệnh `USER appuser` cắt đứt chuỗi tấn công ngay từ bước đầu bằng cách hạ quyền tiến trình xuống user thường (non-root). Dù bị khai thác RCE, kẻ tấn công cũng chỉ có quyền hạn cực kỳ hạn chế bên trong container và không thể thực thi các tác vụ nguy hiểm lên máy host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Người dùng có thể gửi tối đa 20 request trong 2 giây liên tiếp.
Cách đạt được: Người dùng gửi 10 request vào giây 10:00:59 (giây cuối cùng của phút thứ nhất) và gửi tiếp 10 request vào giây 10:01:01 (giây đầu tiên của phút thứ hai). Với cách đếm theo phút đồng hồ, cả hai đợt đều hợp lệ (10 req/phút), nhưng thực chất hệ thống phải chịu 20 request trong khoảng thời gian 2 giây.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhung cost guard phải chặn, và một tình huống ngược lại.

- Khác nhau: Rate limit giới hạn về *tần suất/tốc độ* gọi API (số request / đơn vị thời gian). Cost guard giới hạn về *chi phí/tổng số tiền* phát sinh (ngân sách USD / tháng).
- Rate limit cho qua nhưng Cost guard chặn: User gọi rất chậm (chỉ 2 request/phút), nhưng mỗi request gửi một prompt cực kỳ dài 50,000 tokens khiến chi phí tăng đột biến vượt quá ngân sách tháng $10.0.
- Cost guard cho qua nhưng Rate limit chặn: User mới bắt đầu tháng (chưa tiêu hết ngân sách $10.0) nhưng gửi dồn dập 20 request trong vài giây, bị Rate limit chặn để bảo vệ server khỏi bị quá tải.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự sự kiện:
1. Redis gặp sự cố mất kết nối trong 30 giây.
2. Cả 3 container đều thực thi health check gộp, phát hiện không nối được Redis nên trả về HTTP 503.
3. Orchestrator (Docker/Kubernetes) nhận 503 và tưởng cả 3 container ứng dụng bị sập, nên ra lệnh kill và restart lại toàn bộ 3 container cùng lúc.
4. Khi Redis phục hồi, cả 3 container vẫn đang trong quá trình khởi động lại, không có container nào sẵn sàng phục vụ, làm biến sự cố nhỏ của Redis thành sự cố sập toàn bộ ứng dụng.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Con số `history_length` sẽ tăng giảm thất thường và không liên tục (ví dụ: 0, 1, 0, 2, 1...). Lý do là mỗi request sẽ được Load Balancer điều hướng ngẫu nhiên đến 1 trong 3 container. Nếu dùng dict Python trong RAM, mỗi container chỉ giữ lịch sử riêng của nó, dẫn đến việc agent bị "mất trí nhớ" luân phiên tùy thuộc vào container nhận request.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

- Thông báo lỗi: `Error: Invalid value for '--port': '$PORT' is not a valid integer.` và `/ready` trả về HTTP 503.
- Nguyên nhân: Lệnh `startCommand` trong `railway.toml` không chạy qua shell nên biến `$PORT` bị truyền dạng chuỗi thô chứ không được giải mã thành số cổng. Ngoài ra, app FastAPI chưa nối tới `REDIS_URL` của service Database Redis riêng.
- Cách sửa: Đổi `startCommand` thành `sh -c 'uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}'`, tạo service Redis riêng bằng `railway add --database redis` và gán biến `REDIS_URL` vào service app.
