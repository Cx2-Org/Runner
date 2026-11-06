// Xuất trạng thái văn phòng CÔNG KHAI (đọc từ stdin JSON thô) — chỉ số issue, mã gói, trạng thái, tiến độ, máy, điểm.
// KHÔNG tiêu đề, KHÔNG nội dung comment (repo public). Dùng: node status.js < raw.json > status.json
'use strict';
const S = require('./state');
// Nền tảng từ đầu tiêu đề: [ios] / [desktop/linux] / [mac/ios]… (chỉ lấy tên nền tảng, không lộ tiêu đề).
const plat = t => ((/^\[(?:[^\]\/]+\/)?(ios|android|mac|windows|linux)\]/.exec(t || '') || [])[1]) || '';
const code = t => ((/\]\s+([A-Z]{1,3}\d{1,3}[a-z]?)\b/.exec(t || '') || [])[1]) || '';
let raw = ''; process.stdin.on('data', d => raw += d).on('end', () => {
  const r = JSON.parse(raw), s = S.buildState(r);
  const costOf = n => { const m = /CHI PHÍ: \$([0-9.]+)/.exec((r.closedReport || {})[n] || ''); return m ? Number(m[1]) : null; };
  const lb = (x) => Object.fromEntries(((x && x.bots) || []).map(b => [b.bot, b]));
  const l24 = lb(r.lb24), l7 = lb(r.lb7);
  const out = {
    at: s.at,
    bots: s.bots.map(b => ({ name: b.name, role: b.role, state: b.state, jobs: b.jobs.map(j => ({ number: j.number, code: code(j.title), platform: plat(j.title),
      phase: j.phase, progress: j.progress, model: j.model, machine: j.machine && { os: j.machine.os, startedAt: j.machine.startedAt, status: j.machine.status } })) })),
    machines: s.machines.map(m => { const j = s.bots.flatMap(b => b.jobs.map(x => ({ ...x, bot: b.name }))).find(x => String(x.number) === String(m.issue));
      return { issue: m.issue, os: m.os, status: m.status, startedAt: m.startedAt, platform: j ? plat(j.title) : '', code: j ? code(j.title) : '', bot: j ? j.bot : '' }; }),
    queue: { waiting: s.queue.waiting, blocked: s.queue.blocked, ready: s.queue.ready, next: s.queue.next.map(i => ({ number: i.number, code: code(i.title), bot: i.bot })) },
    done: s.done.map(d => ({ number: d.number, code: code(d.title), bot: d.bot, closedAt: d.closedAt, score: d.score, confidence: d.confidence, cost: costOf(d.number) })),
    // Hạn mức Claude từng nick (0..1): phiên 5 giờ, 7 ngày, giờ reset phiên (epoch giây).
    quota: Object.fromEntries(S.BOTS.map((b, i) => [b.name, (r.quota || {})[String(i + 1)] || null])),
    // Chi phí giá API quy đổi (gói thuê bao không trừ tiền thật): tổng + từng bot, 24 giờ và 7 ngày.
    costs: { total24: (r.lb24 && r.lb24.total && r.lb24.total.cost) || 0, total7: (r.lb7 && r.lb7.total && r.lb7.total.cost) || 0,
      bots: Object.fromEntries(S.BOTS.map(b => [b.name, { cost24: (l24[b.name] || {}).cost || 0, cost7: (l7[b.name] || {}).cost || 0,
        done7: (l7[b.name] || {}).done || 0, avg7: (l7[b.name] || {}).avg ?? null, ptsPerUsd7: (l7[b.name] || {}).ptsPerUsd ?? null }])) },
  };
  process.stdout.write(JSON.stringify(out));
});
