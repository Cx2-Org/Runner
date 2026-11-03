# cutcut-runner

GitHub Actions chạy Claude Code làm checklist trong issue của repo private.

- `dispatch.yml` — 30 phút/lần: lấy issue có label `ci-run` + label nền tảng, mở tối đa `MAX_PARALLEL` job.
- `run-cluster.yml` — 1 issue = 1 job (≤ 6h): làm task → test pass → tick ô → push nhánh `ci/issue-N` → PR.
- `platforms.json` — máy chạy + lệnh test từng nền tảng. Thêm nền tảng = thêm 1 dòng.
- `prompt.md` — luật cho Claude. Việc nguy hiểm → mở issue `need-human` chờ duyệt.

Secrets: `CLAUDE_CODE_OAUTH_TOKEN` (`claude setup-token`), `VIBECUT_PAT` (fine-grained: Contents/Issues/Pull requests RW).
