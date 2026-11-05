# Giao việc tự động cho đội bot Claude — thiết kế

## Ý định
Owner gõ 1 việc bằng lời thường trong topic Telegram "Văn phòng làm việc CutCut" (group "CutCut Thông báo").
Hệ thống tự: tách việc theo nền tảng → duyệt kế hoạch → chia cho 3 "nhân viên" bot → làm, test, mở PR →
báo tiến độ về đúng topic đó. Chạy 24/7 trên GitHub Actions (repo public `Cx2-Org/Runner`, việc thật ở repo
private `nguyenphp/vibecut`), máy owner tắt vẫn chạy. Kẹt thì tự khởi động lại. Hàng chờ sắp cạn thì nhắc owner
nghĩ thêm việc.

Owner nói: "tự chạy liên tục nhận việc", "đứng thì có cơ chế start lại", "by pass tất cả các permission",
"cho 1 con duyệt trước khi làm rồi báo là được", "chia nhân viên ra làm, làm bằng model gì, cũng sub agent",
"sắp hết task thì báo để tao nghĩ thêm task". Không có bước người duyệt — bot trưởng nhóm tự duyệt.

## Đã có sẵn (giữ nguyên, xây tiếp lên)
- `dispatch.yml` (cron 30 phút + tự gọi khi 1 job xong): lấy issue `ci-run` + nhãn nền tảng, mở `run-cluster.yml`
  tới trần `platforms.json._limits`; dọn `ci-running` treo > 6.5 giờ; keepalive chống GitHub tắt cron.
- `run-cluster.yml` + `scripts/work-issue.sh`: 1 job ≤ 6h, làm checklist `- [ ]` của issue theo `prompt.md`
  (superpowers: writing-plans → TDD → verification, chạy app thật chụp ảnh), tick ô, push `ci/issue-N`, PR,
  còn giờ thì `claim-next.sh` nhận issue kế cùng nền tảng.
- Chọn model theo nhãn (README): `model:*` > bug/perf→opus > documentation/i18n→haiku > sonnet; loop không ra
  kết quả thì nâng bậc.
- 3 token Claude `CLAUDE_CODE_OAUTH_TOKEN_1..3`, hết hạn mức tự đổi token kế.
- Telegram: `scripts/tg.sh` gửi vào group/topic (`TG_CHAT_ID`, `TG_THREAD_ID`), bot theo `BOT_NO`
  (`TG_BOT_TOKEN_1..3`). Hiện báo: bắt đầu issue, mỗi vòng, kết thúc, hết hạn mức.

## Đội bot (nhân viên)
| Số | Tên | Token Claude | Vai |
|---|---|---|---|
| 1 | Captain Queenie | `CLAUDE_CODE_OAUTH_TOKEN_1` | trưởng nhóm: nhận việc, tách, duyệt, giao; rảnh thì làm như nhân viên |
| 2 | Iron Man | `_2` | nhân viên |
| 3 | Spider Man | `_3` | nhân viên |

Mọi tin Telegram gửi bằng đúng bot đang làm việc đó (tên bot = người làm).

## Các phần cần xây

### 1. Nhận việc từ Telegram (intake)
- Workflow mới chạy cron ~5 phút (+ `workflow_dispatch`): đọc `getUpdates` của bot Queenie, lấy tin trong
  đúng `TG_CHAT_ID` + `TG_THREAD_ID`, bắt đầu bằng `/giao` (hoặc `/giao@captain_queenie_bot`). Ack bằng `offset`
  để không xử lý lại. Tin không phải `/giao` → bỏ qua, không trả lời.
- Mỗi tin `/giao` → 1 issue "việc lớn" ở vibecut, nhãn `inbox`, body = nguyên văn việc + người gửi + thời gian.
  Queenie trả lời ngay trong topic (reply vào tin gốc): "Đã nhận, đang phân tích → #N".
- Chỉ nhận tin từ group/topic trên. Group private nên mọi thành viên được giao việc.

### 2. Trưởng nhóm tách + duyệt (triage)
Job triage (ubuntu, token 1, model opus, không cần máy ảo) cho mỗi issue `inbox`:
1. **Tách**: đọc việc + CLAUDE.md + cấu trúc repo vibecut, viết kế hoạch: việc này đụng nền tảng nào
   (`ios`, `android`, `mac`, `windows`, `linux`), mỗi nền tảng 1 issue con theo **khuôn chuẩn** (dưới).
   Chỉ tạo issue cho nền tảng việc thật sự đụng tới. Luật port của CLAUDE.md áp dụng (Android chỉ làm mảng
   đã có trên Android).
2. **Duyệt**: một phiên Claude THỨ HAI (cùng token 1, prompt "người duyệt") đọc kế hoạch, soi: đúng ý việc
   gốc, task nhỏ đủ để 1 job ≤ 6h làm xong, mỗi task có cách kiểm tra, không có việc nguy hiểm theo `prompt.md`
   (việc nguy hiểm → tách ra issue `need-human`, không giao bot). Sai thì sửa kế hoạch (tối đa 2 vòng).
3. **Giao**: tạo issue con, gắn nhãn nền tảng + model + `bot:<tên>` + `ci-run`; issue gốc đổi `inbox` → `planned`,
   body thêm danh sách issue con. Queenie báo topic: "Đã duyệt việc #N: tách K issue — #a iOS → Iron Man (opus),
   #b Android → Spider Man (sonnet)…".
4. Không tách được (việc mơ hồ quá) → Queenie hỏi lại owner trong topic, issue gốc nhãn `need-human`.
   Đây là ngoại lệ duy nhất cần owner.

**Khuôn chuẩn issue con** (tiêu đề `[<nền tảng>] <việc ngắn>`):
```
Từ việc #<gốc>: <1 câu việc gốc>
## Mục tiêu
<làm gì, cho ai thấy gì>
## Task
- [ ] <task 1 — nhỏ, 1 đầu ra rõ>
- [ ] ...
## Xong khi
- <lệnh test của nền tảng xanh + test mới cho logic mới>
- <màn nào phải chụp ảnh, trông ra sao>
## Ghi chú
<file/skill liên quan, ràng buộc CLAUDE.md, phụ thuộc issue con khác>
```

**Chọn model** khi tách: theo bảng README (bug/perf/khó → opus, chữ/dịch → haiku, còn lại sonnet), trưởng nhóm
được gắn `model:*` khác nếu task cần. Cơ chế nâng bậc giữ nguyên.

**Chia nhân viên**: gắn `bot:queenie|ironman|spiderman`, rải đều theo số issue đang chạy của từng bot; ưu tiên
Iron Man/Spider Man, Queenie nhận khi 2 bot kia đang bận. `run-cluster` dùng token theo nhãn `bot:*`
(thiếu nhãn → giữ cách cũ `ISSUE % n`). Token hết hạn mức → đổi bot kế như hiện tại, báo topic ai thay ai.

### 3. Bỏ qua mọi hỏi quyền + sub agent
- Mọi phiên `claude -p` (triage, duyệt, làm việc) chạy `--dangerously-skip-permissions`, bỏ `--allowedTools`.
  Máy ảo GitHub dùng xong là xoá. Luật cấm trong `prompt.md` (push main, force push, R2/CDN/DB, in secret, việc
  nguy hiểm) vẫn giữ — chỉ là luật chữ, không còn chặn bằng quyền.
- `prompt.md` thêm: được dùng sub agent (Agent tool) chạy song song cho việc độc lập trong 1 issue (tìm code,
  viết test, soát review); sub agent tìm kiếm/đọc dùng haiku, sub agent viết code dùng cùng model phiên chính.
  Build/test nặng chỉ 1 cái 1 lúc trong 1 máy.
- Log repo PUBLIC: vẫn không in nội dung Claude ra console (giữ như hiện tại).

### 4. Tự khởi động lại khi kẹt (watchdog)
- Cron dispatch rút từ 30 → ~10 phút.
- Job kẹt: run `run-cluster` đang chạy mà issue nó giữ (`ci-running`) không có hoạt động (comment/commit/sửa
  body) > 60 phút → huỷ run, gỡ `ci-running`, giữ `ci-run`, comment + Telegram "Iron Man đứng hình ở #N, khởi
  động lại". Dispatch lượt sau mở job mới; nhánh `ci/issue-N` giữ phần đã commit.
- Lượt tự khởi động lại của cùng 1 issue tối đa 3 lần; quá → nhãn `need-human`, báo topic.
- Intake/triage cũng có trần thời gian; chết giữa chừng thì issue `inbox` vẫn còn, lượt sau làm lại (idempotent:
  không tạo trùng issue con — kiểm danh sách con đã ghi trong issue gốc).
- Dọn treo 6.5 giờ hiện có giữ nguyên làm lưới cuối.

### 5. Nhắc hàng chờ sắp cạn
- Mỗi lượt dispatch đếm issue `ci-run` chưa `ci-running` (đang chờ) và đang chạy.
- Đang chờ ≤ 1 → Queenie báo topic: "Sắp hết việc: còn X đang làm, Y chờ. Giao thêm bằng /giao …".
- Không spam: tối đa 1 lần mỗi 3 giờ, và chỉ báo lại khi hàng chờ đã từng > 1 rồi tụt xuống. Hết sạch (0 chờ,
  0 chạy) báo 1 lần "Đội rảnh".

### 6. Nền tảng
- `platforms.json` thêm `linux` (`ubuntu-latest`). `windows` + `linux`: vibecut hiện CHƯA có code Windows/Linux;
  lệnh test để trống → dispatch đã có sẵn nhánh "chưa cấu hình" sẽ comment + gỡ `ci-run`. Trưởng nhóm không tạo
  issue windows/linux trừ khi việc gốc nói rõ.
- Nhãn mới ở vibecut: `inbox`, `planned`, `linux`, `bot:queenie`, `bot:ironman`, `bot:spiderman`.

## Không làm (non-goals)
- Không có bước owner bấm duyệt trước khi làm.
- Không làm UI/dashboard mới; Telegram + issue GitHub là đủ.
- Không nhận việc qua kênh khác ngoài topic Telegram (owner vẫn tự tạo issue `ci-run` tay được như cũ).
- Không dựng code Windows/Linux.
- Bot không chat qua lại với owner ngoài: xác nhận nhận việc, báo duyệt, báo tiến độ/kết quả, hỏi lại khi việc mơ hồ,
  nhắc hàng chờ.

## Thất bại dù chạy được (anti-goals)
- Spam topic (mỗi phút 1 tin, nhắc hàng chờ liên tục).
- Tạo issue trùng khi intake/triage chạy lại.
- Bot in secret / code ra log public.
- Bot tự ý làm việc nguy hiểm vì đã bỏ chặn quyền.
- 2 bot làm cùng 1 issue.

## Ràng buộc
- Commit KHÔNG có dòng Co-Authored-By / Generated with (hook vibecut chặn).
- macOS runner tối đa 5 job song song (giới hạn free), tổng 20.
- GitHub cron có thể trễ 5–15 phút; chấp nhận.
- Secrets đã có: `TG_CHAT_ID=-1004420681690`, `TG_THREAD_ID=461`, `TG_BOT_TOKEN_1..3`, 3 token Claude,
  `VIBECUT_PAT` (Contents/Issues/PR RW trên vibecut).

## Để người xây quyết
- Lưu `offset` Telegram và mốc "đã nhắc hàng chờ" ở đâu (gợi ý: body 1 issue ghim ở vibecut, hoặc chỉ dựa vào
  ack `offset` của Telegram).
- Prompt triage/duyệt cụ thể, số vòng sửa kế hoạch.
- Cách đo "không hoạt động 60 phút" (updatedAt issue, commit nhánh, hay heartbeat riêng).
- Gộp triage vào dispatch hay workflow riêng.

## Chốt sau vòng soát (quyết định của người viết thiết kế — owner xem lại)
1. **Telegram**: bot Queenie không có webhook, chỉ intake poll `getUpdates`; privacy mode BẬT → bot chỉ thấy lệnh
   `/giao`, đúng ý. Không công cụ nào khác được poll bot Queenie (gửi tin thì được).
2. **Chống trùng**: ghi `tg:<chat_id>:<message_id>` vào body issue gốc, kiểm trước khi tạo; issue con ghi
   `parent:#N platform:X`, triage chạy lại chỉ tạo phần còn thiếu. Workflow intake/triage có `concurrency`.
3. **`bot:<tên>` chỉ chọn token + tên Telegram**, không giới hạn 1 job/bot (hạn mức tính theo tài khoản, không
   theo job). Rải đều = chọn bot đang giữ ít issue `ci-running` nhất.
4. **Phụ thuộc giữa issue con**: triage ghi `Chờ: #a` trong body khi thật sự phụ thuộc (vd Android port sau
   khi iOS xong theo luật port). Dispatch bỏ qua issue có `Chờ: #a` mà #a còn mở. Không phụ thuộc thì chạy song song.
5. **Kẹt**: watchdog TRONG job — `claude -p` chạy `--output-format stream-json` ghi ra file; vòng canh nền thấy
   file không lớn thêm 45 phút (build iOS sạch dài nhất ~30 phút) → kill phiên Claude đó, `work-issue.sh` mở
   vòng mới làm tiếp, báo topic "khởi động lại". Watchdog NGOÀI job (cho job chết/treo cả máy): dispatch 10 phút/lần
   thấy run `in_progress` mà nhánh `ci/issue-N` + issue không đổi 120 phút → huỷ run, nhả nhãn. Tối đa 3 lần/issue.
6. **Hạn mức**: triage/duyệt dùng token 1, hết hạn mức thì xoay sang 2, 3 như nhân viên.
7. **Repo đích**: chỉ vibecut. cutcut-cloud để sau (cần PAT riêng).
