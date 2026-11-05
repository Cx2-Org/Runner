// Xuất trạng thái văn phòng CÔNG KHAI (đọc từ stdin JSON thô) — chỉ số issue, mã gói, trạng thái, tiến độ, máy, điểm.
// KHÔNG tiêu đề, KHÔNG nội dung comment (repo public). Dùng: node status.js < raw.json > status.json
'use strict';
const S = require('./state');
const code = t => ((/\]\s+([A-Z]{1,3}\d{1,3}[a-z]?)\b/.exec(t || '') || [])[1]) || '';
let raw = ''; process.stdin.on('data', d => raw += d).on('end', () => {
  const s = S.buildState(JSON.parse(raw));
  const out = {
    at: s.at,
    bots: s.bots.map(b => ({ name: b.name, role: b.role, state: b.state, jobs: b.jobs.map(j => ({ number: j.number, code: code(j.title),
      phase: j.phase, progress: j.progress, model: j.model, machine: j.machine && { os: j.machine.os, startedAt: j.machine.startedAt, status: j.machine.status } })) })),
    machines: s.machines.map(m => ({ issue: m.issue, os: m.os, status: m.status, startedAt: m.startedAt })),
    queue: { waiting: s.queue.waiting, blocked: s.queue.blocked, ready: s.queue.ready, next: s.queue.next.map(i => ({ number: i.number, code: code(i.title), bot: i.bot })) },
    done: s.done.map(d => ({ number: d.number, code: code(d.title), bot: d.bot, closedAt: d.closedAt, score: d.score, confidence: d.confidence })),
  };
  process.stdout.write(JSON.stringify(out));
});
