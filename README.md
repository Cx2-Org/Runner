# cutcut-runner

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
