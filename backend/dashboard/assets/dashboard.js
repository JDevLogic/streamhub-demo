
const BASE = '/dashboard/api';
let currentLogLevel = 'ALL';
let logAutoInterval = null;
let activityAutoInterval = null;
let overviewAutoInterval = null;
let sourcesAutoInterval = null;
let sysChart = null;
let _uptimeSec = 0;

function _fmtUptime(s) {
  s = Math.floor(s);
  const d = Math.floor(s / 86400); s %= 86400;
  const h = Math.floor(s / 3600);  s %= 3600;
  const m = Math.floor(s / 60);    s %= 60;
  const parts = [];
  if (d) parts.push(d + 'd');
  if (h) parts.push(h + 'h');
  if (m) parts.push(m + 'm');
  parts.push(s + 's');
  return parts.join(' ');
}
setInterval(() => {
  if (_uptimeSec > 0) {
    _uptimeSec++;
    const str = _fmtUptime(_uptimeSec);
    document.getElementById('uptime').textContent = '· ' + str;
    document.getElementById('kpi-uptime').textContent = str;
  }
}, 1000);
const introExpandedGroups = new Set();
let introSearchTerm = '';
let introSortMode = 'anime_asc';
let introAllCollapsed = false;
let introUserInteracted = false;
/** @type {Record<string, { durationSec: number, updated_at: number }>} */
let introDurationByAnime = {};
let siEndManuallyEdited = false;
let _introEndProgrammatic = false;
/** Si false (ej. Editar), no recalcula el fin al cambiar el inicio */
let introSuggestEndFromAnime = true;

/* ── Time helpers ────────────────────────── */
function secsToMmss(secs) {
  const s = Math.round(secs);
  return Math.floor(s/60) + ':' + String(s%60).padStart(2,'0');
}

function parseTime(raw) {
  const v = raw.trim();
  if (!v) return null;
  const colonMatch = v.match(/^(\d+):(\d{1,2})$/);
  if (colonMatch) {
    const total = parseInt(colonMatch[1])*60 + parseInt(colonMatch[2]);
    return total >= 0 ? total : null;
  }
  const numMatch = v.match(/^(\d+)s?$/);
  if (numMatch) return parseInt(numMatch[1]);
  return null;
}

function buildAutoLabelFromUrl(rawUrl) {
  const clean = (rawUrl || '').trim();
  if (!clean) return '';
  const noQuery = clean.split('?')[0].split('#')[0];
  const chunks = noQuery.split('/').filter(Boolean);
  const slug = chunks[chunks.length - 1] || '';
  if (!slug) return '';

  const epMatch = slug.match(/^(.*?)-(\d+)(?:-[a-z0-9]+)?$/i);
  if (!epMatch) return slug;
  const animeSlug = (epMatch[1] || '').replace(/-+$/g, '');
  const animeName = animeSlug.replace(/-/g, ' ').replace(/\s+/g, ' ').trim();
  const animeTitle = animeName.replace(/\b\w/g, c => c.toUpperCase());
  const epNum = epMatch[2];
  if (!animeTitle || !epNum) return slug;
  return `${animeTitle}-EP${epNum}`;
}

function autoFillLabelFromUrl(force=false) {
  const urlInput = document.getElementById('si-url');
  const labelInput = document.getElementById('si-label');
  if (!urlInput || !labelInput) return;
  if (!force && labelInput.value.trim()) return;
  labelInput.value = buildAutoLabelFromUrl(urlInput.value);
}

function introSortKey(row) {
  const label = (row.label || '').trim();
  const url = (row.episodio_url || '').trim();
  const base = label || buildAutoLabelFromUrl(url) || url;
  const match = base.match(/^(.*?)-EP(\d+)$/i);
  if (match) {
    return {
      anime: match[1].trim().toLowerCase(),
      ep: parseInt(match[2], 10) || 0
    };
  }
  return { anime: base.toLowerCase(), ep: 0 };
}

function introGroupMeta(row) {
  const label = (row.label || '').trim();
  const url = (row.episodio_url || '').trim();
  const fallback = buildAutoLabelFromUrl(url) || url;
  const base = label || fallback;
  const match = base.match(/^(.*?)-EP(\d+)$/i);
  if (match) {
    return {
      animeDisplay: match[1].trim(),
      animeKey: match[1].trim().toLowerCase(),
      ep: parseInt(match[2], 10) || 0,
    };
  }
  return {
    animeDisplay: base,
    animeKey: base.toLowerCase(),
    ep: 0,
  };
}

/** Prefijo estable del slug de episodio (sin numero final), p. ej. jujutsu-kaisen-2nd-season */
function introSlugPrefixKeyFromUrl(rawUrl) {
  const clean = (rawUrl || '').trim();
  if (!clean) return '';
  const noQuery = clean.split('?')[0].split('#')[0];
  const chunks = noQuery.split('/').filter(Boolean);
  const slug = (chunks[chunks.length - 1] || '').toLowerCase();
  const epMatch = slug.match(/^(.*?)-(\d+)(?:-[a-z0-9]+)?$/i);
  if (!epMatch) return slug || '';
  return (epMatch[1] || '').replace(/-+$/g, '').toLowerCase();
}

function introDurationHintKeySetForUrlLabel(url, label) {
  const u = (url || '').trim();
  const lb = (label || '').trim();
  const keys = new Set();
  const add = (k) => { if (k) keys.add(k); };
  add(introSlugPrefixKeyFromUrl(u));
  add(introGroupMeta({ episodio_url: u, label: '' }).animeKey);
  add(introGroupMeta({ episodio_url: u, label: lb }).animeKey);
  return keys;
}

function rebuildIntroDurationHints(rows) {
  introDurationByAnime = {};
  for (const r of rows || []) {
    if (r.no_intro === 1 || r.no_intro === true) continue;
    const start = Number(r.intro_start) || 0;
    const end = Number(r.intro_end) || 0;
    const dur = end - start;
    if (dur <= 0) continue;
    const ts = Number(r.updated_at) || 0;
    const url = (r.episodio_url || '').trim();
    const label = (r.label || '').trim();
    const keySet = introDurationHintKeySetForUrlLabel(url, label);
    for (const key of keySet) {
      const prev = introDurationByAnime[key];
      if (!prev || ts >= prev.updated_at) {
        introDurationByAnime[key] = { durationSec: dur, updated_at: ts };
      }
    }
  }
}

function introAnimeKeyFromForm() {
  const url = document.getElementById('si-url')?.value?.trim() || '';
  const label = document.getElementById('si-label')?.value?.trim() || '';
  return introGroupMeta({ episodio_url: url, label }).animeKey;
}

function getIntroDurationHintForForm() {
  const url = document.getElementById('si-url')?.value?.trim() || '';
  const label = document.getElementById('si-label')?.value?.trim() || '';
  let best = null;
  for (const key of introDurationHintKeySetForUrlLabel(url, label)) {
    const h = introDurationByAnime[key];
    if (!h || h.durationSec <= 0) continue;
    if (!best || h.updated_at >= best.updated_at) best = h;
  }
  return best;
}

function refreshIntroFormDurationHint() {
  const el = document.getElementById('si-duration-hint');
  if (!el) return;
  const hint = getIntroDurationHintForForm();
  if (hint && hint.durationSec > 0) {
    el.textContent = 'Duracion guardada para este anime: ' + hint.durationSec + 's (fin = inicio + ' + hint.durationSec + 's). Ajusta el fin a mano si este episodio es distinto.';
  } else {
    el.textContent = '';
  }
}

function applyIntroEndFromHint(secs) {
  _introEndProgrammatic = true;
  setTimeInput('si-end', secs);
  _introEndProgrammatic = false;
}

function maybeAutofillIntroEnd() {
  if (!introSuggestEndFromAnime) return;
  const hint = getIntroDurationHintForForm();
  if (!hint || hint.durationSec <= 0) return;
  const start = parseTime(document.getElementById('si-start')?.value || '');
  if (start === null) return;
  const end = parseTime(document.getElementById('si-end')?.value || '');
  const invalidRange = end !== null && end <= start;
  if (siEndManuallyEdited && !invalidRange) return;
  if (invalidRange) siEndManuallyEdited = false;
  applyIntroEndFromHint(start + hint.durationSec);
}

function toggleIntroGroup(groupKey) {
  introUserInteracted = true;
  introAllCollapsed = false;
  if (introExpandedGroups.has(groupKey)) introExpandedGroups.delete(groupKey);
  else introExpandedGroups.add(groupKey);
  loadIntros();
}

function onIntroBodyClick(evt) {
  const toggle = evt.target.closest('[data-intro-toggle]');
  if (!toggle) return;
  const key = toggle.getAttribute('data-intro-toggle');
  if (!key) return;
  toggleIntroGroup(key);
}

function setIntroSearch(value) {
  introSearchTerm = (value || '').trim().toLowerCase();
  loadIntros();
}

function setIntroSort(value) {
  introSortMode = value || 'anime_asc';
  loadIntros();
}

function expandAllIntroGroups() {
  introUserInteracted = true;
  introAllCollapsed = false;
  introExpandedGroups.clear();
  loadIntros();
}

function collapseAllIntroGroups() {
  introUserInteracted = true;
  introAllCollapsed = true;
  introExpandedGroups.clear();
  loadIntros();
}

function setTimeInput(id, secs) {
  const el = document.getElementById(id);
  el.value = secsToMmss(Math.round(secs));
  updatePreview(id);
}

function updatePreview(id) {
  const el      = document.getElementById(id);
  const preview = document.getElementById(id+'-preview');
  const secs    = parseTime(el.value);
  if (secs === null) {
    el.classList.remove('ok'); el.classList.add('bad');
    if (preview) { preview.textContent=''; preview.classList.remove('show'); }
  } else {
    el.classList.remove('bad'); el.classList.add('ok');
    if (preview) { preview.textContent = secs+'s'; preview.classList.add('show'); }
  }
}

function timeAgo(ts) {
  const diff = Date.now()/1000 - ts;
  if (diff < 5) return 'ahora';
  if (diff < 60) return Math.round(diff) + 's';
  if (diff < 3600) return Math.round(diff/60) + 'min';
  if (diff < 86400) return Math.round(diff/3600) + 'h';
  return Math.round(diff/86400) + 'd';
}

function statusClass(code) {
  if (code < 300) return 'status-2xx';
  if (code < 400) return 'status-3xx';
  if (code < 500) return 'status-4xx';
  return 'status-5xx';
}

/* ── Navigation ──────────────────────────── */
const navLinks = document.querySelectorAll('.sidebar nav a');
const pages    = document.querySelectorAll('.page');
const titles   = { overview:'Vista general', activity:'Actividad', sources:'Fuentes', metrics:'Metricas', cache:'Cache', intros:'Skip Intro', logs:'Logs', users:'Usuarios', debug:'Debug Console', system:'Sistema' };

navLinks.forEach(link => {
  link.addEventListener('click', e => {
    e.preventDefault();
    const target = link.dataset.page;
    navLinks.forEach(l => l.classList.remove('active'));
    link.classList.add('active');
    pages.forEach(p => { p.classList.remove('active'); if(p.id === 'page-'+target) p.classList.add('active'); });
    document.getElementById('page-title').textContent = titles[target] || target;
    if (target === 'logs') loadLogs();
    if (target === 'users') loadUsers();
    if (target === 'metrics') loadMetrics();
    if (target === 'activity') loadActivity();
    if (target === 'system') loadSystem();
    if (target === 'sources') loadSources();
    manageAutoRefresh(target);
  });
});

function manageAutoRefresh(page) {
  clearInterval(logAutoInterval);
  clearInterval(activityAutoInterval);
  clearInterval(overviewAutoInterval);
  clearInterval(sourcesAutoInterval);
  logAutoInterval = null;
  activityAutoInterval = null;
  overviewAutoInterval = null;
  sourcesAutoInterval = null;

  if (page === 'logs' && document.getElementById('log-auto').checked) {
    logAutoInterval = setInterval(loadLogs, 3000);
  }
  if (page === 'activity' && document.getElementById('activity-auto').checked) {
    activityAutoInterval = setInterval(loadActivity, 4000);
  }
  if (page === 'overview') {
    overviewAutoInterval = setInterval(loadStats, 3000);
  }
  if (page === 'sources') {
    sourcesAutoInterval = setInterval(loadSources, 10000);
  }
}

document.getElementById('log-auto').addEventListener('change', function() {
  const active = document.querySelector('.sidebar nav a.active');
  if (active) manageAutoRefresh(active.dataset.page);
});
document.getElementById('activity-auto').addEventListener('change', function() {
  const active = document.querySelector('.sidebar nav a.active');
  if (active) manageAutoRefresh(active.dataset.page);
});

/* ── Toast ────────────────────────────────── */
function toast(msg, ok=true) {
  const el = document.getElementById('toast');
  const dot = el.querySelector('.toast-dot');
  document.getElementById('toast-msg').textContent = msg;
  dot.style.background = ok ? 'var(--green)' : 'var(--red)';
  el.style.borderColor = ok ? 'rgba(52,211,153,.3)' : 'rgba(248,113,113,.3)';
  el.classList.add('show');
  setTimeout(() => el.classList.remove('show'), 2800);
}

/* ── API ──────────────────────────────────── */
async function apiFetch(path, opts={}) {
  const r = await fetch(BASE + path, opts);
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}

async function loadStats() {
  try {
    const d = await apiFetch('/stats');
    _uptimeSec = d.uptime_s || 0;
    document.getElementById('uptime').textContent = '· ' + _fmtUptime(_uptimeSec);
    document.getElementById('kpi-cpu').textContent = d.cpu_pct.toFixed(1) + '%';
    document.getElementById('cpu-bar').style.width = Math.min(d.cpu_pct, 100) + '%';
    document.getElementById('kpi-mem').textContent = d.mem_pct.toFixed(1) + '%';
    document.getElementById('kpi-mem-detail').textContent = d.mem_used_mb + ' / ' + d.mem_total_mb + ' MB';
    document.getElementById('mem-bar').style.width = Math.min(d.mem_pct, 100) + '%';
    document.getElementById('kpi-uptime').textContent = _fmtUptime(_uptimeSec);
    document.getElementById('kpi-rss').textContent = d.proc_rss_mb + ' MB';
    document.getElementById('kpi-rpm').textContent = d.rpm;
    document.getElementById('kpi-errors').textContent = d.errors;
    document.getElementById('kpi-db').textContent = d.db_size_mb + ' MB';
    document.getElementById('kpi-avgms').textContent = d.avg_ms + ' ms';
    document.getElementById('nav-rpm').textContent = d.rpm + '/m';

    // Chart update
    const timestamp = new Date().getTime();
    if (!sysChart && typeof ApexCharts !== 'undefined') {
      const options = {
        chart: { type: 'area', height: 280, animations: { enabled: true, easing: 'linear', dynamicAnimation: { speed: 1000 } }, toolbar: { show: false }, zoom: { enabled: false } },
        dataLabels: { enabled: false },
        stroke: { curve: 'smooth', width: 2 },
        series: [{ name: 'CPU', data: [] }, { name: 'RAM', data: [] }],
        colors: ['#a78bfa', '#22d3ee'],
        fill: { type: 'gradient', gradient: { shadeIntensity: 1, opacityFrom: 0.35, opacityTo: 0.05, stops: [0, 100] } },
        xaxis: { type: 'datetime', range: 60000, labels: { style: { colors: '#64748b' }, datetimeFormatter: { hour: 'HH:mm:ss', minute: 'HH:mm:ss', second: 'HH:mm:ss' } }, axisBorder: { show: false }, axisTicks: { show: false } },
        yaxis: { min: 0, max: 100, labels: { formatter: (v) => v.toFixed(0) + '%', style: { colors: '#64748b' } } },
        grid: { borderColor: '#1a1a3e', strokeDashArray: 3 },
        legend: { labels: { colors: '#cbd5e1' } },
        tooltip: { theme: 'dark' }
      };
      sysChart = new ApexCharts(document.querySelector("#system-chart"), options);
      sysChart.render();
    }
    
    if (sysChart) {
      sysChart.appendData([
        { data: [{ x: timestamp, y: d.cpu_pct }] },
        { data: [{ x: timestamp, y: d.mem_pct }] }
      ]);
    }
  } catch(e) { console.error(e); }
}

async function loadCache() {
  try {
    const d = await apiFetch('/cache');
    document.getElementById('c-anime').textContent  = d.anime;
    document.getElementById('c-ep').textContent     = d.episodios;
    document.getElementById('c-serv').textContent   = d.servidores;
    document.getElementById('ov-anime').textContent = d.anime;
    document.getElementById('ov-ep').textContent    = d.episodios;
    document.getElementById('ov-serv').textContent  = d.servidores;
    document.getElementById('ov-intro').textContent = d.intros;
  } catch(e) { console.error(e); }
}

async function loadMetrics() {
  try {
    const d = await apiFetch('/metrics');
    const tbody = document.getElementById('metrics-body');
    tbody.innerHTML = '';
    const entries = Object.entries(d);
    if (!entries.length) {
      tbody.innerHTML = '<tr><td colspan="7" style="color:var(--dim);text-align:center;padding:24px">Sin datos aun — aparecen cuando el backend recibe peticiones</td></tr>';
      return;
    }
    entries.sort((a,b) => (b[1].requests||0) - (a[1].requests||0));
    for (const [ep, v] of entries) {
      const hr  = v.hit_rate != null ? (v.hit_rate*100).toFixed(1)+'%' : '--';
      const cls = v.hit_rate == null ? '' : v.hit_rate >= .7 ? 'good' : v.hit_rate >= .4 ? 'warn' : 'bad';
      const row = document.createElement('tr');
      row.innerHTML = `
        <td><span class="mono">${ep}</span></td>
        <td class="num">${v.requests.toLocaleString()}</td>
        <td class="num" style="color:var(--green)">${v.hits.toLocaleString()}</td>
        <td class="num" style="color:var(--red)">${v.misses.toLocaleString()}</td>
        <td>${cls ? '<span class="badge '+cls+'"><span class="badge-dot"></span>'+hr+'</span>' : hr}</td>
        <td class="num">${v.avg_ms != null ? v.avg_ms.toFixed(1) : '--'}</td>
        <td class="num">${v.p95_ms != null ? v.p95_ms.toFixed(1) : '--'}</td>`;
      tbody.appendChild(row);
    }
  } catch(e) { console.error(e); }
}

async function loadActivity() {
  try {
    const search = document.getElementById('activity-search')?.value || '';
    const d = await apiFetch('/activity?limit=100' + (search ? '&path='+encodeURIComponent(search) : ''));
    const s = d.summary;
    document.getElementById('act-rpm').textContent = s.rpm;
    document.getElementById('act-total').textContent = s.total;
    document.getElementById('act-errors').textContent = s.errors;
    document.getElementById('act-avg').textContent = s.avg_ms + ' ms';

    const tbody = document.getElementById('activity-body');
    tbody.innerHTML = '';
    if (!d.requests.length) {
      tbody.innerHTML = '<tr><td colspan="6" style="color:var(--dim);text-align:center;padding:24px">Sin actividad registrada aun</td></tr>';
    } else {
      for (const r of d.requests) {
        const row = document.createElement('tr');
        const time = new Date(r.ts * 1000).toLocaleTimeString('es-ES', {hour:'2-digit',minute:'2-digit',second:'2-digit'});
        row.innerHTML = `
          <td><span class="badge info" style="font-size:.7rem">${r.method}</span></td>
          <td><span class="mono" style="font-size:.75rem">${r.path}</span></td>
          <td class="num"><span class="status-badge ${statusClass(r.status)}">${r.status}</span></td>
          <td class="num" style="font-variant-numeric:tabular-nums">${r.ms.toFixed(0)} ms</td>
          <td style="font-size:.75rem;color:var(--dim)">${r.ip}</td>
          <td style="font-size:.75rem;color:var(--dim);white-space:nowrap">${time}</td>`;
        tbody.appendChild(row);
      }
    }

    // Top paths
    const tpBody = document.getElementById('top-paths-body');
    tpBody.innerHTML = '';
    const maxCount = s.top_paths.length ? s.top_paths[0].count : 1;
    for (const tp of s.top_paths) {
      const pct = s.total ? Math.round(tp.count / s.total * 100) : 0;
      const row = document.createElement('tr');
      row.innerHTML = `
        <td><span class="mono" style="font-size:.78rem">${tp.path}</span></td>
        <td class="num" style="font-weight:600">${tp.count}</td>
        <td>
          <div style="display:flex;align-items:center;gap:8px">
            <div class="bar-track" style="flex:1;height:6px"><div class="bar-fill purple" style="width:${Math.round(tp.count/maxCount*100)}%"></div></div>
            <span style="font-size:.72rem;color:var(--dim);min-width:35px;text-align:right">${pct}%</span>
          </div>
        </td>`;
      tpBody.appendChild(row);
    }
  } catch(e) { console.error(e); }
}

async function loadPending() {
  try {
    const data = await apiFetch('/intros/pending');
    const tbody = document.getElementById('pending-body');
    tbody.innerHTML = '';
    if (!data.length) {
      tbody.innerHTML = '<tr><td colspan="3" style="color:var(--dim);text-align:center;padding:20px">Sin episodios pendientes</td></tr>';
      return;
    }
    for (const r of data) {
      const dt = new Date(r.last_updated * 1000).toLocaleString('es-ES', {day:'2-digit',month:'short',hour:'2-digit',minute:'2-digit'});
      const escapedUrl = r.episodio_url.replace(/'/g,"\\'");
      const isPred = !!r.predicted;
      const badge = isPred
        ? '<span class="badge info" style="margin-left:6px;font-size:.62rem">Predicho</span>'
        : '';
      const dateLabel = isPred ? 'Basado en' : dt;
      const dateCell = isPred
        ? `<span style="color:var(--dim);font-size:.72rem;white-space:nowrap">Tras ep. visto (${dt})</span>`
        : `<span style="color:var(--dim);font-size:.78rem;white-space:nowrap">${dt}</span>`;
      const deleteBtn = isPred
        ? ''
        : `<button class="btn-danger btn-sm" onclick="deletePending('${escapedUrl}')">Eliminar</button>`;
      const row = document.createElement('tr');
      if (isPred) row.style.opacity = '0.78';
      row.innerHTML = `
        <td><span class="mono" style="font-size:.75rem">${r.episodio_url}</span>${badge}</td>
        <td>${dateCell}</td>
        <td style="display:flex;gap:4px;flex-wrap:wrap">
          <button class="btn-primary btn-sm" onclick="prefillIntro('${escapedUrl}')">Configurar</button>
          <button class="btn-ghost btn-sm" onclick="markNoIntro('${escapedUrl}')">Sin intro</button>
          ${deleteBtn}
        </td>`;
      tbody.appendChild(row);
    }
  } catch(e) { console.error(e); }
}

function prefillIntro(url, startSecs=0, endSecs=85) {
  introSuggestEndFromAnime = true;
  siEndManuallyEdited = false;
  document.getElementById('si-url').value   = url;
  document.getElementById('si-label').value = buildAutoLabelFromUrl(url);
  setTimeInput('si-start', startSecs);
  const hint = getIntroDurationHintForForm();
  if (hint && hint.durationSec > 0) {
    applyIntroEndFromHint(startSecs + hint.durationSec);
  } else {
    setTimeInput('si-end', endSecs);
  }
  refreshIntroFormDurationHint();
  document.getElementById('si-url').scrollIntoView({behavior:'smooth', block:'center'});
  document.getElementById('si-url').focus();
}

function editIntro(url, label, startSecs, endSecs) {
  introSuggestEndFromAnime = false;
  siEndManuallyEdited = false;
  document.getElementById('si-url').value   = url;
  document.getElementById('si-label').value = label;
  setTimeInput('si-start', startSecs);
  setTimeInput('si-end',   endSecs);
  refreshIntroFormDurationHint();
  const card = document.getElementById('si-url').closest('.card');
  card.style.borderColor = 'var(--accent)';
  setTimeout(() => card.style.borderColor = '', 1200);
  document.getElementById('si-url').scrollIntoView({behavior:'smooth', block:'center'});
  document.getElementById('si-label').focus();
}

async function loadIntros() {
  try {
    const rawData = await apiFetch('/intros');
    rebuildIntroDurationHints(rawData);
    refreshIntroFormDurationHint();
    maybeAutofillIntroEnd();
    const tbody = document.getElementById('intro-body');
    tbody.innerHTML = '';
    const data = rawData.filter(r => {
      if (!introSearchTerm) return true;
      const meta = introGroupMeta(r);
      const haystack = [
        (r.label || ''),
        (r.episodio_url || ''),
        meta.animeDisplay,
        `ep${meta.ep}`,
        (r.no_intro === 1 || r.no_intro === true) ? 'sin intro' : ''
      ].join(' ').toLowerCase();
      return haystack.includes(introSearchTerm);
    });
    if (!data.length) {
      tbody.innerHTML = '<tr><td colspan="5" style="color:var(--dim);text-align:center;padding:20px">Sin entradas configuradas aun</td></tr>';
      return;
    }
    const groups = new Map();
    for (const r of data) {
      const meta = introGroupMeta(r);
      if (!groups.has(meta.animeKey)) {
        groups.set(meta.animeKey, { animeDisplay: meta.animeDisplay, items: [] });
      }
      groups.get(meta.animeKey).items.push(r);
    }

    const orderedGroups = [...groups.entries()].sort((a, b) => {
      const byName = a[1].animeDisplay.localeCompare(b[1].animeDisplay, 'es');
      if (introSortMode === 'anime_desc') return -byName;
      if (introSortMode === 'updated_desc') {
        const maxA = Math.max(...a[1].items.map(i => i.updated_at || 0));
        const maxB = Math.max(...b[1].items.map(i => i.updated_at || 0));
        if (maxA !== maxB) return maxB - maxA;
      }
      return byName;
    });
    const defaultExpandAll = !introUserInteracted && introExpandedGroups.size === 0 && !introAllCollapsed;

    for (const [groupKey, group] of orderedGroups) {
      const isExpanded = defaultExpandAll || introExpandedGroups.has(groupKey);
      if (defaultExpandAll) introExpandedGroups.add(groupKey);
      const groupRow = document.createElement('tr');
      groupRow.className = 'group-row';
      if (isExpanded) groupRow.classList.add('expanded');
      groupRow.dataset.groupKey = groupKey;
      groupRow.innerHTML = `
        <td colspan="5">
          <button class="group-toggle" data-intro-toggle="${groupKey}">
            <span class="group-caret">▶</span>
            <span class="group-name">${group.animeDisplay}</span>
            <span class="group-count">(${group.items.length} episodios)</span>
          </button>
        </td>`;
      tbody.appendChild(groupRow);

      const sortedItems = [...group.items].sort((a, b) => {
        const ka = introSortKey(a);
        const kb = introSortKey(b);
        if (introSortMode === 'updated_desc') return (b.updated_at || 0) - (a.updated_at || 0);
        if (introSortMode === 'ep_desc') {
          if (ka.ep !== kb.ep) return kb.ep - ka.ep;
        } else {
          if (ka.ep !== kb.ep) return ka.ep - kb.ep;
        }
        return (a.label || a.episodio_url).localeCompare((b.label || b.episodio_url), 'es');
      });

      if (!isExpanded) continue;
      for (const r of sortedItems) {
        const dt = new Date(r.updated_at * 1000).toLocaleString('es-ES', {day:'2-digit',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit'});
        const escapedUrl   = r.episodio_url.replace(/'/g,"\\'");
        const escapedLabel = (r.label||'').replace(/'/g,"\\'");
        const noIntro = r.no_intro === 1 || r.no_intro === true;
        const timeCols = noIntro
          ? `<td colspan="2" class="num" style="text-align:center;font-size:.78rem;color:var(--muted)"><span class="badge info">Sin intro</span></td>`
          : `<td class="num" style="font-family:monospace;color:var(--cyan)">${secsToMmss(r.intro_start)}</td>
          <td class="num" style="font-family:monospace;color:var(--cyan)">${secsToMmss(r.intro_end)}</td>`;
        const row = document.createElement('tr');
        row.innerHTML = `
          <td>
            <span style="color:var(--text);font-weight:500">${r.label || r.episodio_url}</span>
            ${r.label ? '<br/><span class="mono" style="font-size:.7rem;color:var(--dim)">'+r.episodio_url+'</span>' : ''}
          </td>
          ${timeCols}
          <td style="color:var(--dim);font-size:.78rem;white-space:nowrap">${dt}</td>
          <td style="display:flex;gap:4px">
            <button class="btn-primary btn-icon" title="Editar" onclick="editIntro('${escapedUrl}','${escapedLabel}',${r.intro_start},${r.intro_end})"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg></button>
            <button class="btn-danger btn-icon" title="Eliminar" onclick="deleteIntro('${escapedUrl}')"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg></button>
          </td>`;
        tbody.appendChild(row);
      }
    }
  } catch(e) { console.error(e); }
}

async function saveIntro() {
  const url   = document.getElementById('si-url').value.trim();
  const label = document.getElementById('si-label').value.trim() || buildAutoLabelFromUrl(url);
  const start = parseTime(document.getElementById('si-start').value);
  const end   = parseTime(document.getElementById('si-end').value);
  if (!url)          { toast('Falta la URL del episodio', false); return; }
  if (start === null) { toast('Inicio no valido — usa 1:25 o 85', false); return; }
  if (end   === null) { toast('Fin no valido — usa 1:25 o 85',    false); return; }
  if (end <= start)   { toast('El fin debe ser mayor que el inicio', false); return; }
  try {
    await apiFetch('/intros', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({episodio_url:url, label, intro_start:start, intro_end:end, no_intro:false}) });
    toast('Guardado  ' + secsToMmss(start) + ' -> ' + secsToMmss(end));
    document.getElementById('si-url').value   = '';
    document.getElementById('si-label').value = '';
    introSuggestEndFromAnime = true;
    siEndManuallyEdited = false;
    setTimeInput('si-start', 0);
    setTimeInput('si-end', 85);
    refreshIntroFormDurationHint();
    loadIntros(); loadPending(); loadCache();
  } catch(e) { toast('Error: ' + e.message, false); }
}

async function saveIntroNoIntro() {
  const url = document.getElementById('si-url').value.trim();
  const label = document.getElementById('si-label').value.trim() || buildAutoLabelFromUrl(url);
  if (!url) { toast('Falta la URL del episodio', false); return; }
  try {
    await apiFetch('/intros', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({
      episodio_url: url,
      label: label || '',
      intro_start: 0,
      intro_end: 0,
      no_intro: true
    })});
    toast('Guardado sin intro');
    document.getElementById('si-url').value   = '';
    document.getElementById('si-label').value = '';
    introSuggestEndFromAnime = true;
    siEndManuallyEdited = false;
    setTimeInput('si-start', 0);
    setTimeInput('si-end', 85);
    refreshIntroFormDurationHint();
    loadIntros(); loadPending(); loadCache();
  } catch(e) { toast('Error: ' + e.message, false); }
}

async function deleteIntro(url) {
  if (!confirm('Eliminar intro skip?')) return;
  try {
    await apiFetch('/intros', { method:'DELETE', headers:{'Content-Type':'application/json'}, body: JSON.stringify({episodio_url:url}) });
    toast('Eliminado');
    loadIntros(); loadPending(); loadCache();
  } catch(e) { toast('Error: ' + e.message, false); }
}

async function deletePending(url) {
  if (!confirm('Quitar este episodio de pendientes?')) return;
  try {
    await apiFetch('/intros/pending', { method:'DELETE', headers:{'Content-Type':'application/json'}, body: JSON.stringify({episodio_url:url}) });
    toast('Pendiente eliminado');
    loadPending();
  } catch(e) { toast('Error: ' + e.message, false); }
}

async function markNoIntro(url) {
  if (!confirm('Marcar como sin intro? Quedara en configuradas y no volvera a pendientes al verlo de nuevo.')) return;
  const label = buildAutoLabelFromUrl(url);
  try {
    await apiFetch('/intros', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({
      episodio_url: url,
      label: label || '',
      intro_start: 0,
      intro_end: 0,
      no_intro: true
    })});
    toast('Guardado sin intro');
    loadIntros(); loadPending(); loadCache();
  } catch(e) { toast('Error: ' + e.message, false); }
}

async function clearCache(table) {
  const names = {anime_cache:'Anime Detail', episodios_cache:'Episodios', servidores_cache:'Servidores'};
  if (!confirm('Limpiar cache de ' + (names[table]||table) + '?')) return;
  try {
    await apiFetch('/cache/clear', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({table}) });
    toast('Cache limpiada');
    loadCache();
  } catch(e) { toast('Error: ' + e.message, false); }
}

/* ── Logs ─────────────────────────────── */
function setLogLevel(btn) {
  document.querySelectorAll('#log-filters .filter-tab').forEach(t => t.classList.remove('active'));
  btn.classList.add('active');
  currentLogLevel = btn.dataset.level;
  loadLogs();
}

async function loadLogs() {
  const el = document.getElementById('logs');
  const search = document.getElementById('log-search')?.value || '';
  try {
    const params = new URLSearchParams({limit: 200});
    if (currentLogLevel !== 'ALL') params.set('level', currentLogLevel);
    if (search) params.set('search', search);
    const d = await apiFetch('/logs?' + params);

    // Update level counts
    const counts = d.counts || {};
    for (const lvl of ['INFO','WARNING','ERROR']) {
      const el2 = document.getElementById('lc-'+lvl);
      if (el2) el2.textContent = counts[lvl] || 0;
    }
    // Update nav badge with error count
    const errCount = counts['ERROR'] || 0;
    const navErr = document.getElementById('nav-errors');
    navErr.textContent = errCount;
    navErr.style.background = errCount > 0 ? 'rgba(248,113,113,.2)' : '';
    navErr.style.color = errCount > 0 ? 'var(--red)' : '';

    document.getElementById('log-count').textContent = d.lines.length + ' lineas';

    if (!d.lines.length) {
      el.innerHTML = '<span style="color:var(--dim)">Sin logs disponibles</span>';
      return;
    }

    el.innerHTML = d.lines.map(l => {
      const level = l.level || 'INFO';
      // Escape HTML
      const msg = l.message.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
      
      const match = msg.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+\[([A-Z]+)\]\s+([^:]+):\s+(.*)$/);
      if (match) {
        const time = match[1];
        const lvl = match[2];
        const logger = match[3];
        const text = match[4];
        
        let textColor = 'var(--text2)';
        if (level === 'ERROR') textColor = 'var(--red)';
        else if (level === 'WARNING') textColor = 'var(--orange)';
        else if (level === 'INFO') textColor = 'var(--text)';
        else if (level === 'DEBUG') textColor = 'var(--dim)';

        let formattedText = `<span style="color:${textColor}; flex:1; word-break:break-word">${text}</span>`;
        if (logger === 'api.request') {
            formattedText = text.replace(/^(GET|POST|PUT|DELETE|PATCH|OPTIONS) (.*?) HTTP (\d{3}) \((.*?)\) IP: (.*)$/, 
              '<span style="color:var(--accent2); font-weight:600; width:55px; display:inline-block">$1</span> <span style="color:var(--text); flex:1">$2</span> <span style="color:var(--orange); font-family:monospace">HTTP $3</span> <span style="color:var(--dim); font-size:0.9em; margin-left:8px">($4) IP: $5</span>'
            );
            formattedText = `<div style="flex:1; display:flex; gap:8px; word-break:break-word">${formattedText}</div>`;
        }
        
        return `<div class="log-line ${level}" style="display:flex; gap:8px;">
          <span style="color:var(--dim); white-space:nowrap">${time}</span>
          <span class="log-level">${lvl}</span>
          <span style="color:var(--muted); white-space:nowrap">${logger}:</span>
          ${formattedText}
        </div>`;
      }

      return `<div class="log-line ${level}">${msg}</div>`;
    }).join('');

    if (document.getElementById('log-scroll').checked) {
      el.scrollTop = el.scrollHeight;
    }
  } catch(e) { el.textContent = 'Error al cargar logs'; }
}

let logDebounceTimer = null;
function debouncedLoadLogs() {
  clearTimeout(logDebounceTimer);
  logDebounceTimer = setTimeout(loadLogs, 300);
}

async function clearLogs() {
  if (!confirm('Limpiar todos los logs?')) return;
  try {
    await apiFetch('/logs/clear', {method:'POST'});
    toast('Logs limpiados');
    loadLogs();
  } catch(e) { toast('Error: ' + e.message, false); }
}

/* ── Users ──────────────────────────── */
let usersDebounceTimer = null;
function debouncedLoadUsers() {
  clearTimeout(usersDebounceTimer);
  usersDebounceTimer = setTimeout(loadUsers, 300);
}

function fmtDate(ts) {
  if (!ts || ts <= 0) return '--';
  return new Date(ts * 1000).toLocaleString('es-ES', {
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit'
  });
}

async function loadUsers() {
  try {
    const q = (document.getElementById('user-search')?.value || '').trim();
    const params = new URLSearchParams({ limit: '300' });
    if (q) params.set('search', q);
    const rows = await apiFetch('/users?' + params.toString());
    const tbody = document.getElementById('users-body');
    tbody.innerHTML = '';
    if (!rows.length) {
      tbody.innerHTML = '<tr><td colspan="8" style="color:var(--dim);text-align:center;padding:20px">Sin usuarios</td></tr>';
      return;
    }
    for (const u of rows) {
      const id = Number(u.id);
      const kb = ((u.state_size_bytes || 0) / 1024).toFixed(1);
      const row = document.createElement('tr');
      row.innerHTML = `
        <td class="mono">${id}</td>
        <td>${u.username || '--'}</td>
        <td>${u.email || '--'}</td>
        <td style="color:var(--dim)">${fmtDate(u.created_at)}</td>
        <td class="num">${u.active_sessions || 0}</td>
        <td class="num">${kb}</td>
        <td style="color:var(--dim)">${fmtDate(u.state_updated_at)}</td>
        <td style="display:flex;gap:6px">
          <button class="btn-ghost btn-sm" onclick="revokeUserSessions(${id})">Cerrar sesiones</button>
          <button class="btn-danger btn-sm" onclick="deleteUser(${id}, '${(u.username || '').replace(/'/g, "\\'")}')">Eliminar</button>
        </td>
      `;
      tbody.appendChild(row);
    }
  } catch (e) {
    console.error(e);
  }
}

async function revokeUserSessions(userId) {
  if (!confirm('Cerrar TODAS las sesiones de este usuario?')) return;
  try {
    await apiFetch('/users/' + userId + '/sessions/revoke', { method: 'POST' });
    toast('Sesiones revocadas');
    loadUsers();
  } catch (e) {
    toast('Error: ' + e.message, false);
  }
}

async function deleteUser(userId, username) {
  if (!confirm('Eliminar usuario ' + username + ' (ID ' + userId + ')? Esta accion es irreversible.')) return;
  try {
    await apiFetch('/users/' + userId, { method: 'DELETE' });
    toast('Usuario eliminado');
    loadUsers();
  } catch (e) {
    toast('Error: ' + e.message, false);
  }
}

/* ── System ──────────────────────────── */
async function loadSystem() {
  try {
    const d = await apiFetch('/system');
    const grid = document.getElementById('sys-grid');
    const bootDate = new Date(d.boot_time * 1000).toLocaleString('es-ES');
    const startDate = new Date(d.startup_time * 1000).toLocaleString('es-ES');
    grid.innerHTML = `
      <div class="sys-item"><div class="sys-label">Python</div><div class="sys-value">${d.python}</div></div>
      <div class="sys-item"><div class="sys-label">Plataforma</div><div class="sys-value" style="font-size:.82rem">${d.platform}</div></div>
      <div class="sys-item"><div class="sys-label">PID</div><div class="sys-value">${d.pid}</div></div>
      <div class="sys-item"><div class="sys-label">CPUs</div><div class="sys-value">${d.cpu_count}</div></div>
      <div class="sys-item"><div class="sys-label">DB Path</div><div class="sys-value" style="font-size:.75rem;word-break:break-all">${d.db_path}</div></div>
      <div class="sys-item"><div class="sys-label">DB Size</div><div class="sys-value">${d.db_size_mb} MB</div></div>
      <div class="sys-item"><div class="sys-label">Boot del servidor</div><div class="sys-value" style="font-size:.82rem">${bootDate}</div></div>
      <div class="sys-item"><div class="sys-label">Inicio del servicio</div><div class="sys-value" style="font-size:.82rem">${startDate}</div></div>
    `;
    document.getElementById('sys-disk-pct').textContent = d.disk_pct + '%';
    document.getElementById('sys-disk-bar').style.width = d.disk_pct + '%';
    if (d.disk_pct > 85) document.getElementById('sys-disk-bar').className = 'bar-fill purple';
    document.getElementById('sys-disk-used').textContent = d.disk_used_gb + ' GB usado';
    document.getElementById('sys-disk-total').textContent = d.disk_free_gb + ' GB libre / ' + d.disk_total_gb + ' GB total';
  } catch(e) { console.error(e); }
}

/* ── Sources (traffic light) ─────────────── */
function srcRateColor(rate) {
  if (rate === null || rate === undefined) return 'var(--dim)';
  if (rate >= 0.9) return 'linear-gradient(90deg, #059669, var(--green))';
  if (rate >= 0.5) return 'linear-gradient(90deg, #c2410c, var(--orange))';
  return 'linear-gradient(90deg, #b91c1c, var(--red))';
}

function srcTimeAgo(ts) {
  if (!ts) return 'nunca';
  return 'hace ' + timeAgo(ts);
}

function escapeHtml(s) {
  return String(s || '').replace(/[&<>"']/g, c => (
    {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]
  ));
}

async function loadSources() {
  try {
    const d = await apiFetch('/sources');
    const grid = document.getElementById('src-grid');
    const sources = d.sources || [];

    // Sidebar badge: "ok/total" healthy sources
    const okCount = sources.filter(s => s.status === 'green').length;
    document.getElementById('nav-sources').textContent = okCount + '/' + sources.length;

    if (!sources.length) {
      grid.innerHTML = '<div class="src-empty">Sin fuentes registradas</div>';
      return;
    }

    const srcCard = s => {
      const rate = s.success_rate;
      const ratePct = rate !== null && rate !== undefined ? Math.round(rate * 100) : 0;
      const rateTxt = rate !== null && rate !== undefined ? ratePct + '%' : '—';
      const avg = s.avg_ms !== null && s.avg_ms !== undefined ? Math.round(s.avg_ms) + 'ms' : '—';
      const subText = s.total
        ? `${rateTxt} éxito · ${srcTimeAgo(s.last_ok)}`
        : 'sin eventos registrados';
      const errBlock = s.last_error
        ? `<div class="src-err" title="${escapeHtml(s.last_error)}">${escapeHtml(s.last_error)}</div>`
        : '';
      const cats = (s.error_categories || []).slice(0, 3);
      const catsBlock = cats.length
        ? `<div class="src-errcats">${cats.map(c =>
            `<span class="src-cat" title="${escapeHtml(c.label)}: ${c.count}">${escapeHtml(c.label)} <b>${c.count}</b></span>`
          ).join('')}</div>`
        : '';
      // Video servers are exercised by real playback traffic, not synthetic
      // probes — there is no /test probe for them, so only offer Reset.
      const testBtn = s.kind === 'server' ? '' :
        `<button class="btn btn-primary btn-sm" onclick="testSource('${s.name}', this)">Probar ahora</button>`;

      return `
        <div class="src-card ${s.status}" id="src-card-${s.name}">
          <div class="src-glow"></div>
          <div class="src-head">
            <div class="src-name">
              <span class="src-dot"></span>
              ${escapeHtml(s.label)}
            </div>
            <span class="src-kind">${s.kind}</span>
          </div>
          <div class="src-sub">${subText}</div>
          <div class="src-rate-track">
            <div class="src-rate-fill" style="width:${ratePct}%;background:${srcRateColor(rate)}"></div>
          </div>
          <div class="src-stats">
            <div class="src-stat">
              <div class="src-stat-label">OK</div>
              <div class="src-stat-value ok">${s.ok_count}</div>
            </div>
            <div class="src-stat">
              <div class="src-stat-label">Empty</div>
              <div class="src-stat-value empty">${s.empty_count || 0}</div>
            </div>
            <div class="src-stat">
              <div class="src-stat-label">Fail</div>
              <div class="src-stat-value fail">${s.fail_count}</div>
            </div>
            <div class="src-stat">
              <div class="src-stat-label">Avg</div>
              <div class="src-stat-value">${avg}</div>
            </div>
          </div>
          ${errBlock}
          ${catsBlock}
          <div class="src-hist" id="hist-${s.name}" data-open="0"></div>
          <div class="src-actions">
            ${testBtn}
            <button class="btn btn-ghost btn-sm" onclick="loadHistory('${s.name}')">
              Histórico
            </button>
            <button class="btn btn-ghost btn-sm" onclick="resetSource('${s.name}')">
              Reset
            </button>
          </div>
        </div>
      `;
    };

    const servers  = sources.filter(s => s.kind === 'server');
    const services = sources.filter(s => s.kind !== 'server');
    let html = '';
    if (services.length) {
      html += '<div class="src-section">Fuentes &amp; APIs</div>';
      html += services.map(srcCard).join('');
    }
    if (servers.length) {
      html += '<div class="src-section">Servidores de vídeo</div>';
      html += servers.map(srcCard).join('');
    }
    grid.innerHTML = html;
  } catch(e) {
    console.error(e);
    document.getElementById('src-grid').innerHTML =
      '<div class="src-empty">Error cargando fuentes</div>';
  }
}

async function testSource(name, btn) {
  const originalText = btn.textContent;
  btn.disabled = true;
  btn.textContent = 'Probando…';
  try {
    const r = await apiFetch('/sources/' + name + '/test', { method: 'POST' });
    if (r.ok) {
      toast(`${name}: OK (${Math.round(r.elapsed_ms)}ms)`, true);
    } else {
      toast(`${name}: ${r.error || 'error'}`, false);
    }
  } catch(e) {
    toast(`${name}: ${e.message || 'error'}`, false);
  } finally {
    btn.disabled = false;
    btn.textContent = originalText;
    loadSources();
  }
}

async function resetSource(name) {
  if (!confirm(`¿Borrar las estadísticas de ${name}?`)) return;
  try {
    await apiFetch('/sources/' + name + '/reset', { method: 'POST' });
    toast(`${name}: estadísticas reseteadas`, true);
    loadSources();
  } catch(e) {
    toast(`Error: ${e.message || e}`, false);
  }
}

function _lastNDays(n) {
  const out = [];
  const today = new Date();
  for (let i = n - 1; i >= 0; i--) {
    const x = new Date(today);
    x.setDate(today.getDate() - i);
    out.push(x.getFullYear() + '-' +
      String(x.getMonth() + 1).padStart(2, '0') + '-' +
      String(x.getDate()).padStart(2, '0'));
  }
  return out;
}

function _stackBar(ok, empty, fail, max, label) {
  const okH  = Math.round(ok / max * 100);
  const badH = Math.round((empty + fail) / max * 100);
  const title = `${label} — ${ok} ok · ${empty} empty · ${fail} fail`;
  return `<div class="src-hbar" title="${title}">
            <div class="src-hbar-bad" style="height:${badH}%"></div>
            <div class="src-hbar-ok" style="height:${okH}%"></div>
          </div>`;
}

async function loadHistory(name) {
  const box = document.getElementById('hist-' + name);
  if (!box) return;
  // Toggle: a second click collapses the panel.
  if (box.dataset.open === '1') {
    box.innerHTML = '';
    box.dataset.open = '0';
    return;
  }
  box.dataset.open = '1';
  box.dataset.days = box.dataset.days || '7';
  renderHistory(name);
}

function histRange(name, days) {
  const box = document.getElementById('hist-' + name);
  if (!box) return;
  box.dataset.days = String(days);
  renderHistory(name);
}

async function renderHistory(name) {
  const box = document.getElementById('hist-' + name);
  if (!box) return;
  const days = parseInt(box.dataset.days || '7', 10);
  const rangeBtns = [7, 30].map(n =>
    `<button class="src-range-btn ${n === days ? 'active' : ''}" onclick="histRange('${name}',${n})">${n}d</button>`
  ).join('');
  const head =
    `<div class="src-hist-head">
       <span class="src-hist-title">Histórico · ${days} días (hora del servidor)</span>
       <span class="src-range">${rangeBtns}</span>
     </div>`;
  box.innerHTML = head + '<div class="src-hist-msg">Cargando histórico…</div>';
  try {
    const d = await apiFetch('/sources/' + name + '/history?days=' + days);

    const hours = d.by_hour || [];
    const hTotals = hours.map(h => h.ok + h.empty + h.fail);
    const grand = hTotals.reduce((a, b) => a + b, 0);
    if (!grand) {
      box.innerHTML = head +
        `<div class="src-hist-msg">Sin datos en los últimos ${days} días</div>`;
      return;
    }
    const hMax = Math.max(1, ...hTotals);
    const hBars = hours.map(h =>
      _stackBar(h.ok, h.empty, h.fail, hMax, String(h.hour).padStart(2, '0') + ':00')
    ).join('');

    const dmap = {};
    (d.by_day || []).forEach(r => { dmap[r.day] = r; });
    const allDays = _lastNDays(days);
    const dTotals = allDays.map(day => {
      const r = dmap[day];
      return r ? r.ok + r.empty + r.fail : 0;
    });
    const dMax = Math.max(1, ...dTotals);
    const dBars = allDays.map(day => {
      const r = dmap[day] || { ok: 0, empty: 0, fail: 0 };
      return _stackBar(r.ok, r.empty, r.fail, dMax, day);
    }).join('');
    const sd = s => s.slice(5);  // MM-DD

    box.innerHTML = head +
      `<div class="src-hist-sub">Eventos por hora</div>
       <div class="src-hist-bars">${hBars}</div>
       <div class="src-hist-axis"><span>0h</span><span>6h</span><span>12h</span><span>18h</span><span>23h</span></div>
       <div class="src-hist-sub">Tendencia diaria</div>
       <div class="src-hist-bars">${dBars}</div>
       <div class="src-hist-axis"><span>${sd(allDays[0])}</span><span>${sd(allDays[allDays.length - 1])}</span></div>`;
  } catch(e) {
    box.innerHTML = head +
      '<div class="src-hist-msg">Error cargando histórico</div>';
  }
}

function onSiStartTimeChanged() {
  updatePreview('si-start');
  maybeAutofillIntroEnd();
}

// Live preview for smart time inputs
document.getElementById('si-start')?.addEventListener('input', onSiStartTimeChanged);
document.getElementById('si-start')?.addEventListener('change', onSiStartTimeChanged);
document.getElementById('si-end')  ?.addEventListener('input', () => {
  if (!_introEndProgrammatic) siEndManuallyEdited = true;
  updatePreview('si-end');
});
document.getElementById('si-url')  ?.addEventListener('input', () => {
  introSuggestEndFromAnime = true;
  siEndManuallyEdited = false;
  autoFillLabelFromUrl(false);
  refreshIntroFormDurationHint();
  maybeAutofillIntroEnd();
});
document.getElementById('si-label')?.addEventListener('input', () => {
  refreshIntroFormDurationHint();
  maybeAutofillIntroEnd();
});
document.getElementById('intro-body')?.addEventListener('click', onIntroBodyClick);

// Initialize
introSuggestEndFromAnime = true;
siEndManuallyEdited = false;
setTimeInput('si-start', 0);
setTimeInput('si-end', 85);

/* ── Debug Console ─────────────────────── */
let _dbgSelectedAnime = null;
let _dbgSelectedEp = null;

function _dbgStatus(id, html) { document.getElementById(id).innerHTML = html; }
function _dbgSpinner(msg) { return `<span class="dbg-spinner"></span>${msg}`; }
function _dbgTime(ms) { return `<span class="dbg-timing">${ms} ms</span>`; }

async function debugSearch() {
  const q = document.getElementById('dbg-search').value.trim();
  if (!q) return;
  const btn = document.getElementById('dbg-search-btn');
  btn.disabled = true;
  // Reset downstream sections
  document.getElementById('dbg-episodes-section').style.display = 'none';
  document.getElementById('dbg-servers-section').style.display = 'none';
  document.getElementById('dbg-resolve-section').style.display = 'none';
  _dbgStatus('dbg-search-status', _dbgSpinner('Buscando...'));
  document.getElementById('dbg-search-results').innerHTML = '';
  try {
    const d = await apiFetch('/debug/search?q=' + encodeURIComponent(q));
    const items = d.results || [];
    let timing = _dbgTime(d.elapsed_ms);
    if (d.error) {
      _dbgStatus('dbg-search-status', `<span class="dbg-error">Error: ${d.error}</span> ${timing}`);
    } else {
      _dbgStatus('dbg-search-status', `${items.length} resultado${items.length!==1?'s':''} ${timing}`);
    }
    if (!items.length) {
      document.getElementById('dbg-search-results').innerHTML = '<div class="dbg-empty">Sin resultados</div>';
      btn.disabled = false;
      return;
    }
    let html = '';
    for (const a of items) {
      const title = a.titulo || a.title || 'Sin titulo';
      const url = a.url || a.enlace || '';
      const cover = a.imagen || a.cover || a.poster || '';
      const tipo = a.tipo || a.type || '';
      html += `<div class="dbg-anime-row" onclick="debugSelectAnime(this)" data-url="${url.replace(/"/g,'&quot;')}" data-title="${title.replace(/"/g,'&quot;')}">`;
      if (cover) html += `<img src="${cover}" alt="" loading="lazy" onerror="this.style.display='none'"/>`;
      html += `<div class="dbg-info"><div class="dbg-title">${title}</div>`;
      if (tipo) html += `<div class="dbg-meta">${tipo}</div>`;
      html += `<div class="dbg-url">${url}</div></div></div>`;
    }
    document.getElementById('dbg-search-results').innerHTML = html;
  } catch(e) {
    _dbgStatus('dbg-search-status', `<span class="dbg-error">Error: ${e.message}</span>`);
  }
  btn.disabled = false;
}

async function debugSelectAnime(el) {
  const url = el.dataset.url;
  const title = el.dataset.title;
  if (!url) return;
  _dbgSelectedAnime = { url, title };
  // Highlight selected
  document.querySelectorAll('.dbg-anime-row').forEach(r => r.style.borderColor = 'transparent');
  el.style.borderColor = 'var(--cyan)';
  // Show episodes section, hide downstream
  const epSec = document.getElementById('dbg-episodes-section');
  epSec.style.display = 'block';
  document.getElementById('dbg-servers-section').style.display = 'none';
  document.getElementById('dbg-resolve-section').style.display = 'none';
  document.getElementById('dbg-ep-anime').textContent = '— ' + title;
  _dbgStatus('dbg-ep-status', _dbgSpinner('Cargando episodios...'));
  document.getElementById('dbg-ep-list').innerHTML = '';
  epSec.scrollIntoView({ behavior: 'smooth', block: 'start' });

  try {
    const d = await apiFetch('/debug/episodes?url=' + encodeURIComponent(url));
    const eps = d.episodes || [];
    let timing = _dbgTime(d.elapsed_ms);
    if (d.error) {
      _dbgStatus('dbg-ep-status', `<span class="dbg-error">Error: ${d.error}</span> ${timing}`);
    } else {
      _dbgStatus('dbg-ep-status', `${d.count} episodio${d.count!==1?'s':''} ${timing}`);
    }
    if (!eps.length) {
      document.getElementById('dbg-ep-list').innerHTML = '<div class="dbg-empty">Sin episodios</div>';
      return;
    }
    let html = '';
    for (const ep of eps) {
      const num = ep.numero ?? ep.number ?? '?';
      const epUrl = ep.enlace || ep.url || '';
      html += `<div class="dbg-ep-row" onclick="debugSelectEp(this)" data-url="${epUrl.replace(/"/g,'&quot;')}" data-num="${num}">`;
      html += `<span class="ep-num">EP ${num}</span>`;
      html += `<span class="ep-url">${epUrl}</span>`;
      html += `</div>`;
    }
    document.getElementById('dbg-ep-list').innerHTML = html;
  } catch(e) {
    _dbgStatus('dbg-ep-status', `<span class="dbg-error">Error: ${e.message}</span>`);
  }
}

async function debugSelectEp(el) {
  const url = el.dataset.url;
  const num = el.dataset.num;
  if (!url) return;
  _dbgSelectedEp = { url, num };
  // Highlight
  document.querySelectorAll('.dbg-ep-row').forEach(r => r.style.background = '');
  el.style.background = 'var(--hover)';
  // Show servers section, hide resolve
  const srvSec = document.getElementById('dbg-servers-section');
  srvSec.style.display = 'block';
  document.getElementById('dbg-resolve-section').style.display = 'none';
  document.getElementById('dbg-srv-ep').textContent = '— EP ' + num;
  _dbgStatus('dbg-srv-status', _dbgSpinner('Scrapeando servidores de todas las fuentes...'));
  document.getElementById('dbg-srv-sources').innerHTML = '';
  document.getElementById('dbg-srv-list').innerHTML = '';
  srvSec.scrollIntoView({ behavior: 'smooth', block: 'start' });

  try {
    const d = await apiFetch('/debug/servers?url=' + encodeURIComponent(url));
    const srvs = d.servers || [];
    let timing = _dbgTime(d.elapsed_ms);
    if (d.error) {
      _dbgStatus('dbg-srv-status', `<span class="dbg-error">Error: ${d.error}</span> ${timing}`);
    } else {
      _dbgStatus('dbg-srv-status', `${d.count} servidor${d.count!==1?'es':''} encontrado${d.count!==1?'s':''} ${timing}`);
    }

    // Per-source chips
    const ps = d.per_source || {};
    let chips = '';
    for (const [src, info] of Object.entries(ps)) {
      const color = info.ok ? 'var(--green)' : 'var(--red)';
      const count = (info.servers || []).length;
      const label = info.ok ? `${count} srv` : (info.error || 'error').substring(0, 40);
      chips += `<span class="dbg-source-chip"><span class="dot" style="background:${color}"></span>${src} <span class="src-ms">${info.elapsed_ms}ms — ${label}</span></span>`;
    }
    document.getElementById('dbg-srv-sources').innerHTML = chips;

    if (!srvs.length) {
      document.getElementById('dbg-srv-list').innerHTML = '<div class="dbg-empty">Ningun servidor encontrado</div>';
      return;
    }
    let html = '';
    for (const s of srvs) {
      const name = s.servidor || 'Desconocido';
      const link = s.enlace || '';
      const src  = s._source || '';
      html += `<div class="dbg-srv-row">`;
      html += `<span class="srv-name">${name}</span>`;
      if (src) html += `<span class="srv-tag">${src}</span>`;
      html += `<span class="srv-url" title="${link.replace(/"/g,'&quot;')}">${link}</span>`;
      html += `<button class="btn-success btn-sm" onclick="debugResolve('${link.replace(/'/g,"\\'")}', '${name.replace(/'/g,"\\'")}')">Resolver</button>`;
      html += `</div>`;
    }
    document.getElementById('dbg-srv-list').innerHTML = html;
  } catch(e) {
    _dbgStatus('dbg-srv-status', `<span class="dbg-error">Error: ${e.message}</span>`);
  }
}

async function debugResolve(embedUrl, serverName) {
  if (!embedUrl) return;
  const resSec = document.getElementById('dbg-resolve-section');
  resSec.style.display = 'block';
  _dbgStatus('dbg-res-status', _dbgSpinner(`Resolviendo ${serverName}...`));
  document.getElementById('dbg-res-output').innerHTML = '';
  resSec.scrollIntoView({ behavior: 'smooth', block: 'start' });

  try {
    const d = await apiFetch('/debug/resolve?url=' + encodeURIComponent(embedUrl));
    const streams = d.streams || [];
    let timing = _dbgTime(d.elapsed_ms);

    if (d.error) {
      _dbgStatus('dbg-res-status', `<span class="dbg-error">Error: ${d.error}</span> ${timing}`);
      return;
    }
    if (d.supported === false) {
      _dbgStatus('dbg-res-status', `<span class="dbg-error">Servidor no soportado — sin extractor</span> ${timing}`);
      return;
    }
    if (!streams.length) {
      _dbgStatus('dbg-res-status', `<span class="dbg-error">Sin streams (extractor no encontro URL)</span> ${timing}`);
      return;
    }
    _dbgStatus('dbg-res-status', `${streams.length} stream${streams.length!==1?'s':''} desde ${serverName} ${timing}`);
    let html = '';
    for (const st of streams) {
      const q = st.quality || st.label || 'default';
      const u = st.url || '';
      html += `<div class="dbg-stream-row">`;
      html += `<span class="str-quality">${q}</span>`;
      html += `<div class="str-url">${u}</div>`;
      html += `<div class="str-actions">`;
      html += `<button class="btn-ghost btn-sm" onclick="navigator.clipboard.writeText('${u.replace(/'/g,"\\'")}');toast('URL copiada')">Copiar URL</button>`;
      html += `<a href="${u}" target="_blank" rel="noopener" class="btn-ghost btn-sm" style="text-decoration:none">Abrir</a>`;
      html += `</div></div>`;
    }
    document.getElementById('dbg-res-output').innerHTML = html;
  } catch(e) {
    _dbgStatus('dbg-res-status', `<span class="dbg-error">Error: ${e.message}</span>`);
  }
}

function loadAll() { loadStats(); loadCache(); loadMetrics(); loadIntros(); loadPending(); loadLogs(); loadActivity(); loadUsers(); loadSources(); }

loadAll();
setInterval(loadStats,   10000);
setInterval(loadCache,   30000);
setInterval(loadMetrics, 30000);
// Start auto-refresh for logs since it starts on overview
manageAutoRefresh('overview');
