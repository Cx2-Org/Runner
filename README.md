# cutcut-runner

GitHub Actions chạy Claude Code làm checklist trong issue của repo private.

- `dispatch.yml` — 30 phút/lần: lấy issue có label `ci-run` + label nền tảng, mở tối đa `MAX_PARALLEL` job.
- `run-cluster.yml` — 1 issue = 1 job (≤ 6h): làm task → test pass → tick ô → push nhánh `ci/issue-N` → PR.
- `platforms.json` — máy chạy + lệnh test từng nền tảng. Thêm nền tảng = thêm 1 dòng.
- `prompt.md` — luật cho Claude. Việc nguy hiểm → mở issue `need-human` chờ duyệt.

Secrets: `CLAUDE_CODE_OAUTH_TOKEN` (`claude setup-token`), `VIBECUT_PAT` (fine-grained: Contents/Issues/Pull requests RW).

## Chọn model cho từng issue

| Ưu tiên | Điều kiện (label của issue) | Model |
|---|---|---|
| 1 | `model:opus` / `model:sonnet` / `model:haiku` | đúng model đó |
| 2 | `bug`, `perf` (debug, tìm nguyên nhân gốc) | opus |
| 3 | `documentation`, `i18n` (chữ, dịch, tài liệu) | haiku |
| 4 | còn lại (tính năng, test, port) | sonnet |

Vòng nào không có commit lẫn tick mà model chưa phải opus → tự nâng lên opus làm tiếp; opus cũng bế tắc mới bỏ.
