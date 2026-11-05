# Giao việc tự động qua Telegram — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Owner gõ `/giao <việc>` trong topic Telegram → bot trưởng nhóm tách theo nền tảng, tự duyệt, giao cho 3 bot làm (bỏ qua hỏi quyền, có sub agent), kẹt tự chạy lại, sắp hết việc thì nhắc.

**Architecture:** Thêm vào repo runner hiện có (bash + jq + gh + GitHub Actions). Logic quyết định nằm trong hàm bash thuần ở `scripts/lib.sh`, test bằng `tests/run.sh` (bash + fixture JSON, stub `gh`/`curl` qua PATH). Workflow mới `intake.yml` (cron 5 phút: Telegram → issue `inbox` → triage). `dispatch.yml` thêm watchdog ngoài + nhắc hàng chờ + phụ thuộc. `work-issue.sh` thêm watchdog trong job.

**Tech Stack:** bash 5, jq, gh CLI, curl, GitHub Actions, Claude Code CLI (`claude -p`).

**Spec:** `docs/superpowers/specs/2026-11-05-giao-viec-tu-dong-design.md` (đọc cả mục "Chốt sau vòng soát").

## Global Constraints
- Repo runner PUBLIC: console chỉ in số issue/đếm; KHÔNG in nội dung Claude, tiêu đề issue, token. `tg.sh` không in gì.
- Repo việc: `nguyenphp/vibecut` (`$REPO`), token `VIBECUT_PAT`. Chỉ vibecut.
- Bot: 1=queenie (Captain Queenie), 2=ironman (Iron Man), 3=spiderman (Spider Man) ↔ `CLAUDE_CODE_OAUTH_TOKEN_1..3`, `TG_BOT_TOKEN_1..3`.
- Telegram: `TG_CHAT_ID=-1004420681690`, `TG_THREAD_ID=461` (đã là secret). Lệnh nhận: `/giao` hoặc `/giao@captain_queenie_bot`.
- Commit runner/vibecut: KHÔNG dòng Co-Authored-By/Generated with. Commit kèm path.
- macOS ≤ 5 job, tổng ≤ 20 (giữ `_limits`).
- Mọi `claude -p`: `--dangerously-skip-permissions`.
- Nhãn mới (vibecut): `inbox`, `planned`, `linux`, `bot:queenie`, `bot:ironman`, `bot:spiderman`.

## Review Focus
1. Cùng 1 tin `/giao` bị xử lý 2 lần (intake chạy chồng, offset mất) → chỉ 1 issue gốc (khoá `tg:<chat>:<msg_id>`). Test ở Task 4.
2. Tin `/giao` trống hoặc tin ở topic khác / chat khác → bỏ qua, không tạo issue. Test ở Task 4.
3. Phiên Claude đang build iOS sạch 30 phút không in gì → KHÔNG bị watchdog giết (ngưỡng 45 phút đo trên stream-json). Test ở Task 3.
4. Issue con có `Chờ: #a` mà #a đã đóng → được dispatch; #a còn mở → bỏ qua. Test ở Task 6.
5. Nhắc hàng chờ không spam khi dispatch chạy mỗi 10 phút. Test ở Task 6.

---

### Task 1: Thư viện hàm + khung test

**Files:**
- Create: `scripts/lib.sh`, `tests/run.sh`, `tests/fixtures/` (thư mục)
- Modify: `README.md` (mục "Test": `bash tests/run.sh`)

**Interfaces:**
- Produces: `tests/run.sh` chạy mọi `tests/test_*.sh`, mỗi file định nghĩa hàm `test_*`; helper `assert_eq <expected> <actual> <name>`; in `PASS n / FAIL m`, exit 1 nếu FAIL. `scripts/lib.sh` chỉ chứa hàm (source được, không chạy gì khi source).

- [ ] Step 1: `tests/test_smoke.sh` với `test_lib_sources() { source scripts/lib.sh; assert_eq ok ok smoke; }`
- [ ] Step 2: `bash tests/run.sh` → FAIL (chưa có run.sh/lib.sh)
- [ ] Step 3: viết `tests/run.sh` + `scripts/lib.sh` rỗng
- [ ] Step 4: `bash tests/run.sh` → `PASS 1 / FAIL 0`
- [ ] Step 5: commit `test: khung test bash cho runner`

### Task 2: Bỏ hỏi quyền, sub agent, chọn bot theo nhãn

**Files:**
- Modify: `.github/workflows/run-cluster.yml` (bước `claude`), `scripts/work-issue.sh` (dòng `claude -p`), `prompt.md`, `scripts/lib.sh`
- Test: `tests/test_bot.sh`

**Interfaces:**
- Produces: `bot_no_from_labels "<labels csv>"` → in `1|2|3` theo `bot:queenie|ironman|spiderman`, rỗng nếu không có. `bot_name <n>` → `Captain Queenie|Iron Man|Spider Man`.

- [ ] Step 1: test `bot_no_from_labels ",ios,bot:ironman,ci-run,"` = `2`; `",ios,"` = ``; `bot_name 3` = `Spider Man`
- [ ] Step 2: chạy → FAIL
- [ ] Step 3: viết 2 hàm trong `lib.sh`
- [ ] Step 4: chạy → PASS
- [ ] Step 5: `run-cluster.yml`: bỏ biến `ALLOWED`; vòng chọn token: nếu issue có nhãn `bot:*` thì `ti` = index của bot đó trong `nos`, còn lại giữ `ISSUE % n`. `work-issue.sh`: thay `--allowedTools "$ALLOWED"` bằng `--dangerously-skip-permissions`. `tg.sh` dùng tên thay `[Bot n]`: `[$(bot_name $n)]` (source lib.sh).
- [ ] Step 6: `prompt.md` thêm mục "Sub agent": được dùng Agent tool chạy song song việc độc lập (tìm code, viết test, soát lại); sub agent tìm/đọc dùng `model: haiku`, sub agent viết code dùng model phiên chính; chỉ 1 build/test nặng 1 lúc trên máy. Thêm 1 dòng: "Đã bỏ chặn quyền — luật Cấm/NGUY HIỂM bên dưới là luật cứng, tự giữ."
- [ ] Step 7: commit `runner: bỏ hỏi quyền, sub agent, chọn bot theo nhãn bot:*`

### Task 3: Watchdog trong job

**Files:**
- Modify: `scripts/work-issue.sh` (vòng Claude), `scripts/lib.sh`
- Test: `tests/test_watchdog.sh` (claude giả = script `sleep`/`echo` trong PATH)

**Interfaces:**
- Produces: `run_with_idle_kill <idle_seconds> <outfile> -- <cmd...>` chạy cmd ghi stdout vào outfile; nếu outfile không lớn thêm trong `idle_seconds` thì kill cả nhóm tiến trình, trả exit 124; xong bình thường trả exit của cmd. Kiểm mỗi `min(60, idle/3)` giây.

- [ ] Step 1: test: cmd `bash -c 'echo a; sleep 5'` với idle 2 → exit 124 trong < 5s; cmd `bash -c 'for i in 1 2 3; do echo $i; sleep 1; done'` với idle 2 → exit 0; outfile có `3`.
- [ ] Step 2: chạy → FAIL
- [ ] Step 3: viết hàm (`setsid`/`set -m` + `kill -- -pgid`; macOS runner không có setsid → dùng `perl -e 'setpgrp; exec @ARGV'`)
- [ ] Step 4: chạy → PASS
- [ ] Step 5: `work-issue.sh`: `claude -p ... --output-format stream-json --verbose` qua `run_with_idle_kill 2700 ../claude-$round.jsonl -- claude ...`. Kết quả cuối = dòng `{"type":"result"...}` cuối file → ghi ra `../claude-$round.json` để code cũ (`.result`, `.is_error`) giữ nguyên. Exit 124 → `tg "#$ISSUE: phiên Claude im 45 phút, khởi động lại"`, không tính là "không tick" (không nâng model, không break; vòng sau chạy tiếp). Tối đa 3 lần idle-kill/issue/job → break.
- [ ] Step 6: commit `runner: watchdog trong job — Claude im 45 phút thì mở phiên mới`

### Task 4: Intake Telegram → issue gốc

**Files:**
- Create: `scripts/intake.sh`, `.github/workflows/intake.yml`
- Modify: `scripts/lib.sh`
- Test: `tests/test_intake.sh`, `tests/fixtures/tg_updates.json` (gồm: /giao đúng topic, /giao@captain_queenie_bot, /giao trống, /giao topic khác, /giao chat khác, tin thường)

**Interfaces:**
- Produces: `tg_parse_giao <updates.json> <chat_id> <thread_id>` → in JSON lines `{"key":"tg:<chat>:<msg_id>","msg_id":N,"text":"<việc>","from":"<tên>","date":N,"update_id":N}` chỉ cho tin hợp lệ (text sau lệnh khác rỗng). `tg_max_update_id <updates.json>` → số lớn nhất hoặc rỗng.
- `intake.sh`: getUpdates (bot 1, `allowed_updates=["message"]`) → với mỗi tin: nếu `gh issue list --label inbox,planned --search "<key> in:body"` đã có → bỏ; không thì `gh issue create --label inbox` (body: việc nguyên văn + `<!-- tg:... -->` + người gửi/thời gian), reply tin gốc (`reply_parameters.message_id`) "Đã nhận → #N". Cuối cùng ack `getUpdates?offset=max+1`.
- `intake.yml`: cron `*/5 * * * *` + `workflow_dispatch`, `concurrency: {group: intake}`, ubuntu; bước 1 intake, bước 2 triage (Task 5) cho mọi issue `inbox`.

- [ ] Step 1: test parse với fixture → đúng 2 tin (đúng topic, có text), key/text đúng; `tg_max_update_id` đúng
- [ ] Step 2: chạy → FAIL
- [ ] Step 3: viết hàm jq
- [ ] Step 4: chạy → PASS
- [ ] Step 5: test intake idempotent: stub `gh` (script ghi lệnh ra file, `issue list` trả issue có key) → chạy `intake.sh` 2 lần với cùng fixture → `issue create` gọi đúng 1 lần cho mỗi key
- [ ] Step 6: viết `intake.sh` + `intake.yml` → PASS
- [ ] Step 7: commit `runner: nhận việc /giao từ topic Telegram → issue inbox`

### Task 5: Triage — trưởng nhóm tách + duyệt + giao

**Files:**
- Create: `scripts/triage.sh`, `prompts/triage.md`, `prompts/review.md`, `scripts/setup-labels.sh`
- Modify: `scripts/lib.sh`, `platforms.json` (thêm `"linux": {"runs_on":"ubuntu-latest","test":""}`), `dispatch.sh` (`PLATFORMS` thêm `linux`)
- Test: `tests/test_triage.sh`

**Interfaces:**
- Consumes: `bot_name`, `tg.sh`.
- Produces: kế hoạch JSON `/tmp/plan.json`: `{"ok":true,"children":[{"platform":"ios","title":"...","body":"<khuôn chuẩn>","model":"opus|sonnet|haiku","depends_on":["android"]}],"need_human":[{"title":"...","body":"..."}],"question":null}`. `pick_bot <ci-running counts json>` → `2|3|1` (ít việc nhất, hoà thì ưu tiên 2, 3, rồi 1). `validate_plan <plan.json>` exit 0/1 (platform ∈ ios/android/mac/windows/linux, mỗi body có `## Task` với ≥1 `- [ ]` và `## Xong khi`).
- `triage.sh <issue>`: phiên 1 `claude -p "$(cat prompts/triage.md)" --model opus --dangerously-skip-permissions` trong checkout vibecut, ghi `/tmp/plan.json`; phiên 2 `prompts/review.md` đọc issue gốc + plan, sửa tại chỗ, tối đa 2 vòng, phải ra `validate_plan` OK. Rồi tạo issue con theo thứ tự (để biết số #) — mỗi con ghi `<!-- parent:#N platform:X -->`; `depends_on` → dòng `Chờ: #a` trong body; nhãn `<platform>`, `model:<m>`, `bot:<pick_bot>`, `ci-run`. Bỏ qua con đã tồn tại (tìm `parent:#N platform:X`). `need_human` → issue `need-human`. `question` khác null → Queenie hỏi trong topic, issue gốc thêm `need-human`, dừng. Xong: issue gốc `inbox`→`planned`, body thêm danh sách con; Telegram: "Đã duyệt việc #N: tách K issue — #a iOS → Iron Man (opus), …".
- Token: thử 1 → 2 → 3 khi hết hạn mức (dùng lại cách bắt lỗi quota của work-issue.sh).
- `prompts/triage.md`: khuôn chuẩn issue con (copy nguyên từ spec), luật chọn model (README), luật port Android (CLAUDE.md vibecut), task nhỏ cho job ≤ 6h, không tạo windows/linux trừ khi việc gốc nói rõ, việc nguy hiểm (prompt.md) → `need_human`.
- `prompts/review.md`: người duyệt soi đúng ý gốc / đủ nhỏ / có "Xong khi" / không nguy hiểm; sửa plan.json, ghi `"ok":true`.

- [ ] Step 1: test `validate_plan` với 3 fixture (đúng, platform lạ, thiếu `## Xong khi`) → 0/1/1; `pick_bot '{"1":0,"2":1,"3":0}'` = `3`, `'{"1":0,"2":0,"3":0}'` = `2`
- [ ] Step 2: chạy → FAIL
- [ ] Step 3: viết hàm → PASS
- [ ] Step 4: test triage idempotent với stub `gh` + `claude` giả (copy fixture plan) → chạy 2 lần, mỗi platform chỉ 1 `issue create`
- [ ] Step 5: viết `triage.sh`, prompts, `setup-labels.sh` (`gh label create ... --force` cho 6 nhãn mới) → PASS
- [ ] Step 6: chạy `bash scripts/setup-labels.sh` thật 1 lần (REPO=nguyenphp/vibecut)
- [ ] Step 7: commit `runner: trưởng nhóm tách việc theo nền tảng, tự duyệt, giao bot`

### Task 6: Dispatch — phụ thuộc, watchdog ngoài, nhắc hàng chờ

**Files:**
- Modify: `scripts/dispatch.sh`, `.github/workflows/dispatch.yml` (cron `*/10 * * * *`; env `TG_*` để gửi tin), `scripts/lib.sh`
- Test: `tests/test_dispatch.sh`

**Interfaces:**
- Produces: `blocked_by <body>` → in các số `#a` từ dòng `Chờ: #a, #b`. `queue_alert <waiting> <running> <state.json> <now>` → in `low|idle|none` và state mới (JSON `{"last":epoch,"armed":bool,"idle_sent":bool}`): `low` khi waiting ≤ 1 VÀ armed VÀ now-last ≥ 10800, rồi armed=false; waiting > 1 → armed=true, idle_sent=false; waiting=0 & running=0 & !idle_sent → `idle`.
- State lưu ở body issue ghim "Runner trạng thái" (tạo nếu chưa có, nhãn `runner-state`), đọc/ghi bằng `gh issue view/edit`.
- Watchdog ngoài: run `run-cluster` `in_progress` có issue `ci-running` mà `updatedAt` issue VÀ commit cuối nhánh `ci/issue-N` cũ hơn 120 phút → `gh run cancel`, gỡ `ci-running`, comment `Runner: khởi động lại (lần k/3)`, Telegram. Đếm k = số comment bắt đầu bằng "Runner: khởi động lại". k > 3 → gỡ `ci-run`, thêm `need-human`, Telegram.

- [ ] Step 1: test `blocked_by` ("Chờ: #12, #15" → `12 15`; không có → rỗng); `queue_alert` 5 ca: (3,2,armed) none+armed; (1,2,armed,last cũ) low; (1,2 lần 2 ngay sau) none; (0,0) idle; (0,0 lần 2) none
- [ ] Step 2: chạy → FAIL
- [ ] Step 3: viết hàm → PASS
- [ ] Step 4: `dispatch.sh`: bỏ issue có `blocked_by` mà #a còn OPEN; thêm watchdog ngoài; cuối lượt gọi `queue_alert`, `low` → Queenie: "Sắp hết việc: còn X đang làm, Y chờ. Giao thêm bằng /giao …", `idle` → "Đội rảnh, chưa có việc."
- [ ] Step 5: `bash tests/run.sh` → tất cả PASS
- [ ] Step 6: commit `runner: dispatch 10 phút, chờ issue phụ thuộc, tự khởi động lại job kẹt, nhắc hàng chờ`

### Task 7: Chạy thật end-to-end

- [ ] Step 1: README cập nhật (luồng `/giao`, nhãn, bot, watchdog, nhắc hàng chờ); push `Cx2-Org/Runner` main
- [ ] Step 2: bật `dispatch.yml` + `intake.yml` (`gh workflow enable`)
- [ ] Step 3: owner (hoặc bot 1 gửi thay) gõ trong topic: `/giao [thử] thêm 1 unit test nhỏ cho hàm thuần bất kỳ ở iOS và Android, không sửa code app`
- [ ] Step 4: kiểm: ≤ 15 phút có reply "Đã nhận → #N"; issue gốc → `planned`; 2 issue con ios/android đúng khuôn + nhãn bot/model; Telegram báo duyệt; job chạy, báo tiến độ bằng tên bot; PR mở
- [ ] Step 5: ghi kết quả + link vào `docs/superpowers/plans/` (mục cuối file này), commit
