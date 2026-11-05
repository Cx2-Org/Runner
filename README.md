# cutcut-runner

## Giao việc (Telegram)

Gõ trong topic **Văn phòng làm việc CutCut** (group *CutCut Thông báo*): `/giao <việc bằng lời thường>`.

1. `intake.yml` (5 phút/lần) — Captain Queenie đọc `/giao` → issue `inbox` ở vibecut, trả lời "Đã nhận → #N".
2. Trưởng nhóm (`scripts/triage.sh`, opus): tách theo nền tảng (ios/android/mac/windows/linux) thành issue con
   đúng khuôn (Mục tiêu / Task / Xong khi / Ghi chú), phiên Claude thứ 2 duyệt (≤ 2 vòng), gắn `model:*`,
   `bot:queenie|ironman|spiderman` (bot ít việc nhất), `ci-run`; phụ thuộc ghi `Chờ: #a`. Việc nguy hiểm → `need-human`.
   Việc mơ hồ → Queenie hỏi lại trong topic, gỡ `need-human` ở issue gốc là tách lại.
3. `dispatch.yml` (10 phút/lần) mở job; issue có `Chờ: #a` đợi #a đóng.
4. Job (`run-cluster.yml`) chạy Claude **bỏ qua mọi hỏi quyền**, được dùng sub agent; bot báo Telegram bằng tên mình.

| Bot | Tài khoản Claude | Telegram |
|---|---|---|
| Captain Queenie (trưởng nhóm) | `CLAUDE_CODE_OAUTH_TOKEN_1` | `TG_BOT_TOKEN_1` |
| Iron Man | `_2` | `TG_BOT_TOKEN_2` |
| Spider Man | `_3` | `TG_BOT_TOKEN_3` |

Kẹt: Claude im 65 phút → giết phiên, mở phiên mới (≤ 3 lần/job). Job im 180 phút → huỷ, chạy lại (≤ 3 lần, rồi `need-human`).
Hàng chờ còn ≤ 1 → Queenie nhắc "Sắp hết việc" (≤ 1 lần/3 giờ); hết sạch → "Đội rảnh" 1 lần.
Trạng thái nhắc lưu ở issue nhãn `runner-state` (đừng đóng). Nhãn tạo bằng `bash scripts/setup-labels.sh`.

Secrets thêm: `TG_CHAT_ID`, `TG_THREAD_ID`, `TG_BOT_TOKEN_1..3`.

## Cũ

GitHub Actions chạy Claude Code làm checklist trong issue của repo private.

- `dispatch.yml` — 30 phút/lần: lấy issue có label `ci-run` + label nền tảng, mở tối đa `MAX_PARALLEL` job.
- `run-cluster.yml` — 1 issue = 1 job (≤ 6h): làm task → test pass → tick ô → push nhánh `ci/issue-N` → PR.
- `platforms.json` — máy chạy + lệnh test từng nền tảng. Thêm nền tảng = thêm 1 dòng.
- `prompt.md` — luật cho Claude. Việc nguy hiểm → mở issue `need-human` chờ duyệt.

Secrets: `CLAUDE_CODE_OAUTH_TOKEN_1`, `_2`, `_3` (3 tài khoản Claude, mỗi acc `claude setup-token`; issue rải đều, acc hết hạn mức tự đổi acc kế; `CLAUDE_CODE_OAUTH_TOKEN` cũ vẫn nhận), `VIBECUT_PAT` (fine-grained: Contents/Issues/Pull requests RW).

## Chọn model cho từng issue

| Ưu tiên | Điều kiện (label của issue) | Model |
|---|---|---|
| 1 | `model:opus` / `model:sonnet` / `model:haiku` | đúng model đó |
| 2 | `bug`, `perf` (debug, tìm nguyên nhân gốc) | opus |
| 3 | `documentation`, `i18n` (chữ, dịch, tài liệu) | haiku |
| 4 | còn lại (tính năng, test, port) | sonnet |

Loop không ra kết quả (vòng không tick thêm ô nào, hoặc Claude báo `CẦN-MODEL-MẠNH` sau 5 lần sửa cùng một lỗi) → nâng 1 bậc haiku → sonnet → opus. Opus 2 vòng liền vẫn không tick → bỏ.

## Test

`bash tests/run.sh` — hàm thuần ở `scripts/lib.sh`, stub `gh`/`curl`/`claude` qua PATH.
