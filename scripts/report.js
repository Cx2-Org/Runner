// Báo cáo HTML đẹp, tự chứa (CSS nhúng), mở tốt trên điện thoại. Dùng: node report.js <morning|issue|split> < data.json > out.html
'use strict';
const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const BOT = { 'Captain Queenie': '👩‍✈️', 'Iron Man': '🦾', 'Spider Man': '🕷' };
const money = v => v == null ? '–' : `$${Number(v).toFixed(2)}`;
const scoreCls = s => s == null ? '' : s >= 8 ? 'hi' : s >= 6 ? 'mid' : 'lo';
// Markdown tối giản cho phần bot tự viết: tiêu đề, gạch đầu dòng, **đậm**, `code`, ``` khối ```. Thoát HTML trước.
function md(src) {
  const out = []; let list = false, code = false;
  for (const raw of String(src || '').split('\n')) {
    if (raw.trim().startsWith('```')) { if (list) { out.push('</ul>'); list = false; } out.push(code ? '</code></pre>' : '<pre><code>'); code = !code; continue; }
    if (code) { out.push(esc(raw)); continue; }
    let l = esc(raw).replace(/\*\*(.+?)\*\*/g, '<b>$1</b>').replace(/`([^`]+)`/g, '<code>$1</code>');
    const h = /^(#{1,4})\s+(.*)$/.exec(l), li = /^\s*[-*]\s+(.*)$/.exec(l);
    if (li) { if (!list) { out.push('<ul>'); list = true; } out.push(`<li>${li[1]}</li>`); continue; }
    if (list) { out.push('</ul>'); list = false; }
    if (h) out.push(`<h${Math.min(4, h[1].length + 2)}>${h[2]}</h${Math.min(4, h[1].length + 2)}>`);
    else if (l.trim()) out.push(`<p>${l}</p>`);
  }
  if (list) out.push('</ul>'); if (code) out.push('</code></pre>');
  return out.join('\n');
}
const page = (title, body) => `<!doctype html><html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)}</title><style>
:root{--bg:#0e0f11;--card:#1a1b1f;--line:#2b2d33;--fg:#f1f2f4;--mut:#9a9ca6;--brand:#5BE316;--warn:#f0b54a;--bad:#f08a80;--blue:#7cb2ff}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.55 -apple-system,system-ui,"Segoe UI",Roboto,sans-serif;padding:20px 16px 40px}
.wrap{max-width:760px;margin:0 auto;display:flex;flex-direction:column;gap:16px}
header h1{margin:0;font-size:22px}header p{margin:4px 0 0;color:var(--mut);font-size:13px}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:10px}
.stat{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:12px 14px}.stat b{display:block;font-size:26px;line-height:1.1}.stat span{color:var(--mut);font-size:12.5px}
section{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:14px 16px}
section h2{margin:0 0 10px;font-size:14px;letter-spacing:.04em;text-transform:uppercase;color:var(--mut)}
table{width:100%;border-collapse:collapse;font-size:14px}th{text-align:left;color:var(--mut);font-weight:600;font-size:12px;padding:6px 6px;border-bottom:1px solid var(--line)}
td{padding:8px 6px;border-bottom:1px solid var(--line);vertical-align:top}tr:last-child td{border-bottom:0}td.n{text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap}
.hi{color:var(--brand);font-weight:700}.mid{color:var(--warn);font-weight:700}.lo{color:var(--bad);font-weight:700}
.pill{display:inline-block;background:#24262c;border:1px solid var(--line);border-radius:999px;padding:1px 9px;font-size:12px;color:var(--mut);margin-right:4px}
.rank{font-size:18px;width:28px}.win{background:linear-gradient(90deg,rgba(91,227,22,.12),transparent)}
ul{margin:6px 0;padding-left:20px}li{margin:3px 0}a{color:var(--blue)}code{background:#24262c;border-radius:5px;padding:1px 5px;font-size:13px}
pre{background:#0b0c0e;border:1px solid var(--line);border-radius:10px;padding:10px;overflow:auto}pre code{background:none;padding:0}
.empty{color:var(--mut)}.note{border-left:3px solid var(--brand);padding:6px 10px;color:#d7dbe0;background:#16181c;border-radius:6px}
.task{display:flex;gap:8px;padding:6px 0;border-bottom:1px solid var(--line)}.task:last-child{border-bottom:0}
.cta{background:#16211a;border:1px solid #2c4a2f;border-radius:12px;padding:12px 14px}.cta code{background:#0e1a10}
</style></head><body><div class="wrap">${body}</div></body></html>`;

const issueLink = (repo, n) => `<a href="https://github.com/${esc(repo)}/issues/${n}">#${n}</a>`;
const list = (rows, f) => rows && rows.length ? rows.map(f).join('') : '<p class="empty">Không có</p>';

function leaderboard(lb) {
  if (!lb || !lb.bots) return '';
  const medal = ['🥇', '🥈', '🥉'];
  return `<section><h2>🏆 Hiệu quả 7 ngày · tổng ${money(lb.total.cost)}</h2><table>
  <tr><th></th><th>Bot</th><th class="n">Chi phí</th><th class="n">Xong</th><th class="n">Điểm TB</th><th class="n">$/việc</th><th class="n">Điểm/$</th></tr>
  ${lb.bots.map((b, i) => `<tr class="${i === 0 && b.ptsPerUsd != null ? 'win' : ''}"><td class="rank">${b.ptsPerUsd != null ? medal[i] || '' : ''}</td>
  <td>${BOT[b.bot] || ''} ${esc(b.bot)}<br><span class="pill">${b.sessions} lượt</span></td><td class="n">${money(b.cost)}</td><td class="n">${b.done}</td>
  <td class="n ${scoreCls(b.avg)}">${b.avg ?? '–'}</td><td class="n">${money(b.perDone)}</td><td class="n"><b>${b.ptsPerUsd ?? '–'}</b></td></tr>`).join('')}
  </table><p class="empty" style="margin:8px 0 0;font-size:12px">Chi phí là giá quy đổi theo bảng giá API (gói thuê bao không trừ tiền thật). Điểm/$ càng cao càng hiệu quả.</p></section>`;
}

function morning(d) {
  const c = d.counts || {};
  return page(`Báo cáo sáng ${d.date}`, `<header><h1>☀️ Báo cáo sáng ${esc(d.date)}</h1><p>Captain Queenie tổng hợp lúc 8:00</p></header>
  <div class="stats"><div class="stat"><b class="hi">${c.done ?? 0}</b><span>✅ Xong 24 giờ</span></div><div class="stat"><b>${c.run ?? 0}</b><span>⚙️ Đang chạy</span></div>
  <div class="stat"><b>${c.left ?? 0}</b><span>📋 Còn trong hàng</span></div><div class="stat"><b class="${c.human ? 'lo' : ''}">${c.human ?? 0}</b><span>🚧 Kẹt, chờ mày</span></div>
  <div class="stat"><b>${money(c.cost24)}</b><span>💰 Chi phí 24 giờ</span></div></div>
  ${d.ideas && d.ideas.length ? `<section><h2>💡 Đề xuất chờ duyệt</h2>${d.note ? `<p class="note">${esc(d.note)}</p>` : ''}<table>
    ${d.ideas.map(i => `<tr><td style="width:56px">${issueLink(d.repo, i.number)}</td><td>${esc(i.title)}</td></tr>`).join('')}</table>
    <div class="cta" style="margin-top:10px">👉 Gõ trong topic: <code>/duyet ${d.ideas.slice(0, 2).map(i => i.number).join(' ')}</code> để làm · <code>/bo &lt;số&gt;</code> để bỏ</div></section>` : ''}
  <section><h2>✅ Đã xong 24 giờ</h2>${d.done && d.done.length ? `<table><tr><th>Việc</th><th>Bot</th><th class="n">Điểm</th><th class="n">Chi phí</th></tr>
    ${d.done.map(x => `<tr><td>${issueLink(d.repo, x.number)} ${esc(x.title)}</td><td>${BOT[x.bot] || ''}</td><td class="n ${scoreCls(x.score)}">${x.score != null ? x.score + '/10' : '–'}${x.conf != null ? `<br><span class="pill">${x.conf}%</span>` : ''}</td><td class="n">${money(x.cost)}</td></tr>`).join('')}</table>` : '<p class="empty">Chưa có việc xong</p>'}</section>
  ${leaderboard(d.leaderboard)}
  <section><h2>⚙️ Đang chạy</h2>${list(d.running, x => `<div class="task">${BOT[x.bot] || '🤖'} ${issueLink(d.repo, x.number)} ${esc(x.title)}</div>`)}</section>
  <section><h2>📋 Còn lại theo nhánh</h2><table>${(d.byBase || []).map(b => `<tr><td><code>${esc(b.base)}</code></td><td class="n">${b.count} việc</td></tr>`).join('')}</table></section>
  <section><h2>🚧 Kẹt, cần mày xem</h2>${list(d.human, x => `<div class="task">${issueLink(d.repo, x.number)} ${esc(x.title)}</div>`)}</section>`);
}

function issue(d) {
  return page(`#${d.number} ${d.title}`, `<header><h1>${esc(d.icon || '')} #${d.number} ${esc(d.title)}</h1><p>${BOT[d.bot] || ''} ${esc(d.bot || '')} · ${esc(d.status)}</p></header>
  <div class="stats"><div class="stat"><b class="${scoreCls(d.score)}">${d.score != null ? d.score + '/10' : '–'}</b><span>⭐ Điểm</span></div>
  <div class="stat"><b>${d.conf != null ? d.conf + '%' : '–'}</b><span>🎯 Tự tin</span></div><div class="stat"><b>${money(d.cost)}</b><span>💰 Chi phí</span></div>
  <div class="stat"><b>${d.mins ?? '–'}′</b><span>⏱ Thời gian · ${esc(d.model || '')}</span></div></div>
  <section><h2>Task</h2>${list(d.tasks, t => `<div class="task">${t.ok ? '✅' : '❌'} <span>${esc(t.text)}</span></div>`)}</section>
  <section><h2>Liên kết</h2><p>${issueLink(d.repo, d.number)}${d.pr ? ` · <a href="${esc(d.pr)}">Pull request</a>` : ''}</p></section>
  <section><h2>Bot báo cáo chi tiết</h2>${md(d.summary)}</section>`);
}

function split(d) {
  return page(`Chia việc #${d.number}`, `<header><h1>🧩 Chia việc #${d.number}</h1><p>${esc(d.title || '')}</p></header>
  <section><h2>Các phần</h2><table><tr><th>Việc</th><th>Nền tảng</th><th>Bot</th><th>Model</th></tr>
  ${(d.parts || []).map(p => `<tr><td>${issueLink(d.repo, p.number)}${p.wait ? `<br><span class="pill">chờ ${esc(p.wait)}</span>` : ''}</td><td>${esc(p.platform)}</td><td>${BOT[p.bot] || ''} ${esc(p.bot)}</td><td>${esc(p.model)}</td></tr>`).join('')}</table></section>`);
}

let raw = ''; process.stdin.on('data', x => raw += x).on('end', () => {
  const d = JSON.parse(raw), kind = process.argv[2];
  process.stdout.write(({ morning, issue, split })[kind](d));
});
module.exports = { md };
