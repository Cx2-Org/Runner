// Dựng trạng thái văn phòng từ dữ liệu GitHub — hàm thuần, chạy được cả trình duyệt (window.State) lẫn Node (test).
(function (root) {
'use strict';

const BOTS = [
  { label: 'bot:queenie', name: 'Captain Queenie', role: 'Vợ kiêm sếp' },
  { label: 'bot:ironman', name: 'Iron Man', role: 'Nhân viên' },
  { label: 'bot:spiderman', name: 'Spider Man', role: 'Nhân viên' },
];

// Trạng thái bot từ comment tiến độ cuối cùng (khuôn ở prompt.md của runner).
function phaseOf(comment) {
  const b = (comment || '').trim();
  if (/^▶ Plan/.test(b)) return { key: 'plan', text: 'Đang lên plan' };
  if (/^✎ Task/.test(b)) return { key: 'code', text: 'Đang code' };
  if (/^✔/.test(b)) return { key: 'done', text: 'Xong, đang kiểm lại' };
  if (/^BỎ QUA|^CẦN-MODEL-MẠNH/.test(b)) return { key: 'stuck', text: 'Vướng, đang xử lý' };
  if (/^Runner: khởi động lại/.test(b)) return { key: 'restart', text: 'Khởi động lại' };
  if (/^▶ Task/.test(b)) return { key: 'code', text: 'Đang làm' };
  return { key: 'work', text: 'Đang làm' };
}

function scoreOf(text) {
  const m = /ĐIỂM:\s*(\d+(?:\.\d+)?)\/10\s*\|\s*TỰ TIN:\s*(\d+)%/.exec(text || '');
  return m ? { score: Number(m[1]), confidence: Number(m[2]) } : null;
}

const labelsOf = it => (it.labels || []).map(l => (typeof l === 'string' ? l : l.name));
const ticks = body => {
  const done = (body.match(/- \[x\]/gi) || []).length, left = (body.match(/- \[ \]/g) || []).length;
  return { done, total: done + left };
};

// raw = { runs: [...run], open: [...issue], lastComment: {n: body}, closed: [...issue], closedReport: {n: body} }
function buildState(raw, now = Date.now()) {
  const machines = (raw.runs || []).filter(r => r.name === 'run-cluster' || /^issue-/.test(r.display_title || ''))
    .map(r => {
      const [issue, os] = (r.display_title || '').split(' ');
      return { issue: Number((issue || '').replace('issue-', '')) || null, os: os || '?', status: r.status,
        startedAt: r.run_started_at || r.created_at, url: r.html_url };
    });
  const running = (raw.open || []).filter(it => labelsOf(it).includes('ci-running'));
  const waiting = (raw.open || []).filter(it => !labelsOf(it).includes('ci-running'));
  const blocked = waiting.filter(it => /^Chờ: #/m.test(it.body || ''));
  const bots = BOTS.map(b => {
    // Không có nhãn bot → bot theo số issue như run-cluster (ISSUE % 3: 0 Queenie, 1 Iron Man, 2 Spider Man).
    const owner = it => BOTS.find(x => labelsOf(it).includes(x.label)) || BOTS[it.number % 3];
    const jobs = running.filter(it => owner(it) === b).map(it => {
      const c = (raw.lastComment || {})[it.number] || '';
      return { number: it.number, title: it.title, url: it.html_url, phase: phaseOf(c), note: c.split('\n')[0].slice(0, 160),
        progress: ticks(it.body || ''), model: (labelsOf(it).find(l => l.startsWith('model:')) || '').slice(6),
        machine: machines.find(m => m.issue === it.number) || null };
    });
    return { ...b, state: jobs.length ? jobs[0].phase.key : 'idle', jobs };
  });
  const done = (raw.closed || []).map(it => ({ number: it.number, title: it.title, url: it.html_url, closedAt: it.closed_at,
    bot: (BOTS.find(b => labelsOf(it).includes(b.label)) || {}).name || '?', ...(scoreOf((raw.closedReport || {})[it.number]) || {}) }));
  return { at: new Date(now).toISOString(), bots, machines, queue: { waiting: waiting.length, blocked: blocked.length,
    ready: waiting.length - blocked.length, next: waiting.filter(it => !blocked.includes(it)).slice(0, 8)
      .map(it => ({ number: it.number, title: it.title, bot: (BOTS.find(b => labelsOf(it).includes(b.label)) || {}).name || '?' })) },
    done };
}

const api = { BOTS, phaseOf, scoreOf, buildState };
if (typeof module !== 'undefined') module.exports = api; else root.State = api;
})(typeof window !== 'undefined' ? window : globalThis);
