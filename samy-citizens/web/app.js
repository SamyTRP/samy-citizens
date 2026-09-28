'use strict';
/*
  samy-citizens NUI
  - Konuşma paneli (hazır cevap önerileriyle), 3D baloncuklar, yerleşik telefon, yönetim paneli
  - Oyuncu/NPC metinleri her zaman textContent ile basılır (HTML enjeksiyonu yok)
*/
const IN_GAME = typeof GetParentResourceName === 'function';
const RES = IN_GAME ? GetParentResourceName() : 'samy-citizens';

let T = {};
let CFG = { maxChars: 300, focusKey: 'Y' };

// ------------------------------------------------------------------ yardımcılar
function t(key, ...args) {
  let s = T[key] !== undefined ? T[key] : key;
  for (const a of args) s = s.replace('%s', a);
  return s;
}

async function post(name, data) {
  if (!IN_GAME) return DevMock.handle(name, data);
  try {
    const r = await fetch(`https://${RES}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data === undefined ? {} : data),
    });
    return await r.json();
  } catch (e) {
    return null;
  }
}

function el(tag, attrs, ...children) {
  const node = document.createElement(tag);
  if (attrs) {
    for (const [k, v] of Object.entries(attrs)) {
      if (v === undefined || v === null || v === false) continue;
      if (k === 'class') node.className = v;
      else if (k === 'text') node.textContent = v;
      else if (k === 'html') node.innerHTML = v;
      else if (k.startsWith('on') && typeof v === 'function') node.addEventListener(k.slice(2), v);
      else if (k === 'value') node.value = v;
      else if (k === 'checked') node.checked = !!v;
      else node.setAttribute(k, v === true ? '' : v);
    }
  }
  for (const c of children.flat()) {
    if (c === undefined || c === null || c === false) continue;
    node.appendChild(typeof c === 'string' || typeof c === 'number' ? document.createTextNode(String(c)) : c);
  }
  return node;
}

const $ = (id) => document.getElementById(id);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

function toast(msg, kind) {
  const box = $('toast');
  const n = el('div', { class: 'toast ' + (kind || ''), text: msg });
  box.appendChild(n);
  setTimeout(() => n.remove(), 3800);
}

function initials(name) {
  if (!name) return '?';
  const parts = name.trim().split(/\s+/);
  const a = parts[0] ? parts[0][0] : '';
  const b = parts.length > 1 ? parts[parts.length - 1][0] : '';
  return (a + b).toUpperCase() || '?';
}

const MOODS = {
  great: { c: '#6fd28a', m: 'M7.5 13.5 Q12 19 16.5 13.5' },
  good: { c: '#3dd6c6', m: 'M8.5 14.5 Q12 17.2 15.5 14.5' },
  neutral: { c: '#aab4c3', m: 'M9 15.2 L15 15.2' },
  bad: { c: '#f5b85c', m: 'M8.5 16.6 Q12 14 15.5 16.6' },
  awful: { c: '#ef6b6b', m: 'M8 17.2 Q12 12.6 16 17.2' },
};
function moodSvg(key) {
  const m = MOODS[key] || MOODS.neutral;
  return `<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="none" stroke="${m.c}" stroke-width="1.8"/>` +
    `<circle cx="9" cy="10" r="1.3" fill="${m.c}"/><circle cx="15" cy="10" r="1.3" fill="${m.c}"/>` +
    `<path d="${m.m}" fill="none" stroke="${m.c}" stroke-width="1.8" stroke-linecap="round"/></svg>`;
}

function applyStaticStrings() {
  document.querySelectorAll('[data-t]').forEach((n) => { n.textContent = t(n.getAttribute('data-t')); });
  $('cv-send').textContent = t('send');
  $('cv-input').placeholder = t('input_placeholder');
  $('cv-close').title = t('close_hint');
  $('cv-release').title = t('release_hint', CFG.focusKey || 'Y');
  $('cv-hint').textContent = t('convo_hint', CFG.focusKey || 'Y');
  $('ph-input').placeholder = t('phone_placeholder');
  document.querySelectorAll('.tab-btn').forEach((b) => { b.textContent = t('tab_' + b.dataset.tab); });
  $('ad-close').textContent = t('close');
  $('ad-sub').textContent = t('admin_sub');
}

// ------------------------------------------------------------------ KONUŞMA
const Convo = {
  open: false,
  busy: false,
  locked: false,
  data: null,

  show(data) {
    this.open = true;
    this.locked = false;
    this.data = data || {};
    $('cv-log').innerHTML = '';
    $('convo').classList.remove('hidden', 'released');
    $('cv-input').disabled = false;
    $('cv-input').value = '';
    $('cv-input').maxLength = CFG.maxChars || 300;
    this.updateCount();
    this.header(data);
    if (data && data.text) this.addMsg('npc', data.text, data.emotion);
    this.suggest(data && data.suggestions);
    this.thinking(!!(data && data.pending));
    setTimeout(() => $('cv-input').focus(), 30);
  },

  header(d) {
    if (!d) return;
    const name = d.name || '?';
    $('cv-name').textContent = name;
    $('cv-avatar').textContent = d.nameKnown === false ? '?' : initials(name);
    $('cv-subtitle').textContent = d.subtitle || '';
    const st = $('cv-stage');
    st.textContent = d.stageLabel || '';
    st.className = 'badge stage-' + (d.stage || 'stranger');
    $('cv-mood').innerHTML = moodSvg(d.mood);
    $('cv-mood').title = t('mood_' + (d.mood || 'neutral'));
    const rel = d.rel || {};
    $('cv-bar-fam').style.width = clamp(rel.familiarity || 0, 0, 100) + '%';
    const aff = rel.affinity || 0;
    const affBar = $('cv-bar-aff');
    affBar.style.width = clamp(Math.abs(aff), 0, 100) + '%';
    affBar.classList.toggle('neg', aff < 0);
    $('cv-bar-trust').style.width = clamp(rel.trust || 0, 0, 100) + '%';
  },

  addMsg(role, text, emotion) {
    const log = $('cv-log');
    const m = el('div', { class: 'msg ' + role });
    m.appendChild(document.createTextNode(text));
    if (role === 'npc' && emotion && emotion !== 'neutral') {
      m.appendChild(el('span', { class: 'meta', text: t('emotion_' + emotion) }));
    }
    log.appendChild(m);
    log.scrollTop = log.scrollHeight;
  },

  system(text, kind) {
    if (!text) return;
    const log = $('cv-log');
    log.appendChild(el('div', { class: 'msg system ' + (kind || ''), text }));
    log.scrollTop = log.scrollHeight;
  },

  npcMessage(d) {
    this.thinking(false);
    this.data = Object.assign(this.data || {}, d);
    this.header(this.data);
    this.addMsg('npc', d.text, d.emotion);
    if (d.stageChanged) this.system(t('stage_changed', d.stageChanged), 'good');
    for (const u of d.ui || []) this.system(u.text, 'good');
    if (d.suggestions) this.suggest(d.suggestions);
  },

  // hazır cevap önerileri: tıklanınca doğrudan gönderilir
  suggest(list) {
    const box = $('cv-suggest');
    box.innerHTML = '';
    if (this.locked) return;
    for (const s of (list || []).slice(0, 7)) {
      if (typeof s !== 'string' || !s) continue;
      box.appendChild(el('button', { type: 'button', text: s, onclick: () => this.send(s) }));
    }
  },

  send(preset) {
    const input = $('cv-input');
    const v = (typeof preset === 'string' ? preset : input.value).trim();
    if (!v || this.busy || this.locked) return;
    this.addMsg('player', v);
    if (typeof preset !== 'string') input.value = '';
    this.updateCount();
    this.thinking(true);
    post('convo:send', { text: v });
  },

  thinking(on) {
    this.busy = !!on;
    $('cv-typing').classList.toggle('hidden', !on);
    $('cv-send').disabled = !!on || this.locked;
  },

  updateCount() {
    const n = $('cv-input').value.length;
    $('cv-count').textContent = `${n}/${CFG.maxChars || 300}`;
  },

  lock() {
    this.locked = true;
    this.thinking(false);
    $('cv-suggest').innerHTML = '';
    $('cv-input').disabled = true;
    $('cv-send').disabled = true;
  },

  end() {
    if (!this.open) return;
    post('convo:close', {});
    this.close();
  },

  release() {
    $('convo').classList.add('released');
    post('convo:release', {});
  },

  setFocus(on) {
    $('convo').classList.toggle('released', !on);
    if (on) setTimeout(() => $('cv-input').focus(), 30);
  },

  close() {
    this.open = false;
    this.busy = false;
    $('convo').classList.add('hidden');
  },
};

$('cv-send').addEventListener('click', () => Convo.send());
$('cv-close').addEventListener('click', () => Convo.end());
$('cv-release').addEventListener('click', () => Convo.release());
$('cv-input').addEventListener('input', () => Convo.updateCount());
$('cv-input').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') { e.preventDefault(); Convo.send(); }
});

// ------------------------------------------------------------------ BALONCUKLAR
const Bubbles = {
  map: {},
  set(id, text, kind) {
    let b = this.map[id];
    if (!b) {
      b = el('div', { class: 'bubble' });
      b.style.display = 'none';
      $('bubbles').appendChild(b);
      this.map[id] = b;
    }
    b.className = 'bubble ' + (kind || 'npc');
    if (kind === 'thinking') {
      b.innerHTML = '<div class="dots"><span></span><span></span><span></span></div>';
    } else {
      b.textContent = text;
    }
  },
  remove(id) {
    const b = this.map[id];
    if (b) { b.remove(); delete this.map[id]; }
  },
  pos(list) {
    const W = window.innerWidth;
    const H = window.innerHeight;
    for (const p of list || []) {
      const b = this.map[p.id];
      if (!b) continue;
      if (!p.v) { b.style.display = 'none'; continue; }
      b.style.display = 'block';
      b.style.transform = `translate(${(p.x * W).toFixed(1)}px, ${(p.y * H).toFixed(1)}px) translate(-50%, -100%) scale(${p.s})`;
    }
  },
};

// ------------------------------------------------------------------ YERLEŞİK TELEFON
const Phone = {
  open: false,
  contacts: [],
  current: null,
  show(contacts) {
    this.open = true;
    this.contacts = contacts || [];
    $('phone').classList.remove('hidden');
    this.renderList();
  },
  renderList() {
    this.current = null;
    $('ph-title').textContent = t('phone_title');
    $('ph-back').classList.add('hidden');
    $('ph-thread').classList.add('hidden');
    $('ph-input-row').classList.add('hidden');
    const list = $('ph-list');
    list.classList.remove('hidden');
    list.innerHTML = '';
    if (!this.contacts.length) {
      list.appendChild(el('div', { class: 'empty', text: t('phone_empty') }));
      return;
    }
    for (const c of this.contacts) {
      list.appendChild(el('div', { class: 'contact', onclick: () => this.openThread(c) },
        el('div', { class: 'avatar', text: initials(c.name) }),
        el('div', {}, el('div', { class: 'c-name', text: c.name }), el('div', { class: 'c-last', text: c.lastText || c.number || '' }))));
    }
  },
  async openThread(c) {
    this.current = c;
    $('ph-title').textContent = c.name;
    $('ph-back').classList.remove('hidden');
    $('ph-list').classList.add('hidden');
    $('ph-thread').classList.remove('hidden');
    $('ph-input-row').classList.remove('hidden');
    const rows = (await post('phone:thread', { npcId: c.npcId })) || [];
    const th = $('ph-thread');
    th.innerHTML = '';
    for (const r of rows) this.appendMsg(r.direction === 'in' ? 'player' : 'npc', r.text);
    setTimeout(() => $('ph-input').focus(), 30);
  },
  appendMsg(role, text, location) {
    const th = $('ph-thread');
    const m = el('div', { class: 'msg ' + role, text });
    if (location) {
      m.appendChild(el('div', {}, el('button', {
        class: 'small', text: t('phone_mark'),
        onclick: () => post('phone:waypoint', { x: location.x, y: location.y }),
      })));
    }
    th.appendChild(m);
    th.scrollTop = th.scrollHeight;
  },
  send() {
    const input = $('ph-input');
    const v = input.value.trim();
    if (!v || !this.current) return;
    input.value = '';
    this.appendMsg('player', v);
    post('phone:send', { npcId: this.current.npcId, text: v });
  },
  // sakin cevap yazarken 'yazıyor...' baloncuğu
  typing(npcId, on) {
    const old = document.getElementById('ph-typing');
    if (old) old.remove();
    clearTimeout(this.typingTimer);
    if (!on || !this.open || !this.current || this.current.npcId !== npcId) return;
    const th = $('ph-thread');
    th.appendChild(el('div', { class: 'msg npc typing-bubble', id: 'ph-typing' }, el('span'), el('span'), el('span')));
    th.scrollTop = th.scrollHeight;
    this.typingTimer = setTimeout(() => this.typing(npcId, false), 15000);
  },
  incoming(m) {
    this.typing(m.npcId, false);
    const c = this.contacts.find((x) => x.npcId === m.npcId);
    if (c) c.lastText = m.text;
    else this.contacts.unshift({ npcId: m.npcId, name: m.name, number: m.number, lastText: m.text });
    if (this.open && this.current && this.current.npcId === m.npcId) this.appendMsg('npc', m.text, m.location);
    else if (this.open && !this.current) this.renderList();
  },
  close() {
    this.open = false;
    $('phone').classList.add('hidden');
    post('phone:close', {});
  },
};
$('ph-back').addEventListener('click', () => Phone.renderList());
$('ph-close').addEventListener('click', () => Phone.close());
$('ph-send').addEventListener('click', () => Phone.send());
$('ph-input').addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); Phone.send(); } });

// ------------------------------------------------------------------ YÖNETİM PANELİ
const ACT_COLORS = {
  sleep: '#5b6b8c', home_idle: '#8aa0c8', idle: '#9aa3ad', work: '#f5b85c', study: '#f0c674', deliver: '#e8a04c',
  lunch_break: '#8fd18f', eat: '#6fd28a', coffee: '#a3d977', drink: '#c792ea', leisure: '#3dd6c6', exercise: '#5fb3ff',
  shopping: '#ff9e80', fish: '#4dd0e1', lunch: '#8fd18f', free: '#80deea', appointment: '#ff6f91', hospital: '#ef6b6b',
};

function parseTime(s) {
  const m = /^\s*(\d+):(\d\d)\s*$/.exec(s || '');
  return m ? (+m[1]) * 60 + (+m[2]) : null;
}
function fmtTime(min) {
  min = ((Math.floor(min) % 1440) + 1440) % 1440;
  return String(Math.floor(min / 60)).padStart(2, '0') + ':' + String(min % 60).padStart(2, '0');
}
function resolveTok(tok, shift) {
  const p = parseTime(tok);
  if (p !== null) return p;
  const m = /^\s*(shift_[a-z]+)\s*([+-]?)\s*(\d*)\s*$/.exec(tok || '');
  if (!m || !shift) return null;
  const s = parseTime(shift.start);
  let e = parseTime(shift.end);
  if (s === null || e === null) return null;
  if (e <= s) e += 1440;
  let base = null;
  if (m[1] === 'shift_start') base = s;
  else if (m[1] === 'shift_end') base = e;
  else if (m[1] === 'shift_mid') base = Math.round(((s + e) / 2) / 30) * 30;
  if (base === null) return null;
  let off = +(m[3] || 0);
  if (m[2] === '-') off = -off;
  let v = base + off;
  if (v < 0) v += 1440;
  return v;
}

function field(label, input, cls) {
  return el('div', { class: 'f ' + (cls || '') }, el('label', { text: label }), input);
}
function inp(value, attrs) {
  return el('input', Object.assign({ value: value === undefined || value === null ? '' : String(value) }, attrs || {}));
}
function sel(options, value, attrs) {
  const s = el('select', attrs || {});
  for (const o of options) {
    const opt = el('option', { value: o.value, text: o.label });
    if (String(o.value) === String(value)) opt.selected = true;
    s.appendChild(opt);
  }
  return s;
}
function num(v, d) {
  const n = parseFloat(v);
  return Number.isFinite(n) ? n : d;
}

function confirmModal(text) {
  return new Promise((resolve) => {
    const back = el('div', { class: 'modal-back' });
    const close = (v) => { back.remove(); resolve(v); };
    back.appendChild(el('div', { class: 'modal' },
      el('h3', { text: t('confirm_title') }),
      el('div', { class: 'muted', text }),
      el('div', { class: 'actions' },
        el('button', { class: 'ghost', text: t('cancel'), onclick: () => close(false) }),
        el('button', { class: 'danger', text: t('confirm'), onclick: () => close(true) }))));
    document.body.appendChild(back);
  });
}

function formModal(title, fields) {
  return new Promise((resolve) => {
    const back = el('div', { class: 'modal-back' });
    const inputs = {};
    const form = el('div', { class: 'form' });
    for (const f of fields) {
      inputs[f.key] = inp(f.value, { type: f.type || 'text' });
      form.appendChild(field(f.label, inputs[f.key], 'span2'));
    }
    const close = (v) => { back.remove(); resolve(v); };
    back.appendChild(el('div', { class: 'modal' }, el('h3', { text: title }), form,
      el('div', { class: 'actions' },
        el('button', { class: 'ghost', text: t('cancel'), onclick: () => close(null) }),
        el('button', {
          class: 'primary', text: t('save'), onclick: () => {
            const out = {};
            for (const f of fields) out[f.key] = inputs[f.key].value;
            close(out);
          },
        }))));
    document.body.appendChild(back);
  });
}

const Admin = {
  open: false,
  boot: null,
  tab: 'residents',
  timer: null,

  async call(action, payload, quiet) {
    const r = await post('admin', { action, payload });
    if (!r || !r.ok) {
      if (!quiet) toast((r && r.error) || t('err_generic'), 'bad');
      return null;
    }
    return r.data === undefined || r.data === null ? true : r.data;
  },

  show(boot) {
    this.open = true;
    this.boot = boot;
    $('admin').classList.remove('hidden');
    this.switchTab('residents');
  },

  close() {
    this.open = false;
    clearInterval(this.timer);
    $('admin').classList.add('hidden');
    post('admin', { action: 'close' });
  },

  async refreshBoot() {
    const b = await this.call('bootstrap', null, true);
    if (b) this.boot = b;
  },

  switchTab(tab) {
    this.tab = tab;
    clearInterval(this.timer);
    document.querySelectorAll('.tab-btn').forEach((b) => b.classList.toggle('active', b.dataset.tab === tab));
    $('ad-top').innerHTML = '';
    $('ad-body').innerHTML = '';
    if (tab === 'residents') this.residents();
    else if (tab === 'locations') this.locations();
    else if (tab === 'routines') this.routines();
    else if (tab === 'dialogue') this.dialogue();
  },

  locOptions(withEmpty, filterType) {
    const out = withEmpty ? [{ value: '', label: '—' }] : [];
    for (const l of this.boot.locations || []) {
      if (!filterType || l.type === filterType) out.push({ value: l.id, label: `${l.label} (${l.type})` });
    }
    return out;
  },

  // ---------------------------------------------------------------- Sakinler
  async residents() {
    const top = $('ad-top');
    const stats = el('div', { class: 'inline' });
    top.append(stats, el('div', { class: 'grow' }),
      el('button', { text: t('btn_blips'), onclick: async () => { const on = await this.call('toggleBlips'); toast(on === true ? t('blips_on') : t('blips_off')); } }),
      el('button', { text: t('btn_new_resident'), onclick: () => this.residentEditor(null) }),
      el('button', { text: t('btn_generate'), onclick: () => this.generate() }),
      el('button', { text: t('btn_refresh'), onclick: () => load() }));
    const body = $('ad-body');
    const load = async () => {
      if (this.tab !== 'residents' || this.detail) return;
      const d = await this.call('overview', null, true);
      if (!d || this.tab !== 'residents' || this.detail) return;
      stats.innerHTML = '';
      stats.append(
        el('span', { class: 'stat', text: `🕒 ${d.clock} · ${d.weather}` }),
        el('span', { class: 'stat', text: `${t('stat_spawned')}: ${d.spawned}/${d.maxSpawned}` }),
        el('span', { class: 'stat', text: `${t('stat_appointments')}: ${d.appointments}` }));
      body.innerHTML = '';
      const table = el('table', { class: 'grid' });
      table.appendChild(el('thead', {}, el('tr', {},
        ['col_name', 'col_job', 'col_activity', 'col_location', 'col_mood', 'col_needs', ''].map((k) => el('th', { text: k ? t(k) : '' })))));
      const tb = el('tbody');
      for (const r of d.residents) {
        const cls = r.physical ? 'phys' : (r.activity === 'commute' ? 'commute' : (r.inside ? 'inside' : 'abs'));
        const needs = el('div', { class: 'needs', title: `E:${r.needs.energy} A:${r.needs.hunger} S:${r.needs.social} F:${r.needs.fun}` },
          ...['energy', 'hunger', 'social', 'fun'].map((k) => {
            const s = el('span');
            const i = el('i');
            i.style.width = (k === 'hunger' ? 100 - r.needs[k] : r.needs[k]) + '%';
            s.appendChild(i);
            return s;
          }));
        const moodCell = el('td', {});
        const face = el('span', { html: moodSvg(r.moodKey) });
        face.style.cssText = 'display:inline-block;width:20px;height:20px;vertical-align:middle;margin-right:6px';
        face.firstChild.style.cssText = 'width:20px;height:20px';
        moodCell.append(face, el('span', { class: 'muted', text: r.moodReason }));
        tb.appendChild(el('tr', {},
          el('td', {}, el('span', { class: 'dot ' + cls }), el('b', { text: r.name }),
            !r.enabled ? el('span', { class: 'muted', text: ' ' + t('disabled') }) : null,
            r.status !== 'alive' ? el('span', { class: 'badge stage-enemy', text: t('status_' + r.status) }) : null,
            r.convo ? el('span', { class: 'badge stage-friend', text: t('in_convo') }) : null),
          el('td', { class: 'muted', text: r.job }),
          el('td', { text: r.activityLabel + (r.override ? ` [${r.override}]` : '') }),
          el('td', { class: 'muted', text: r.location }),
          moodCell,
          el('td', {}, needs),
          el('td', {}, el('div', { class: 'row-actions' },
            el('button', { class: 'small', text: t('btn_detail'), onclick: () => this.residentDetail(r.id) }),
            el('button', { class: 'small', text: t('btn_teleport'), onclick: () => this.call('teleport', r.id) }),
            el('button', { class: 'small', text: t('btn_summon'), onclick: async () => { if (await this.call('summon', r.id)) toast(t('summoned')); } })))));
      }
      table.appendChild(tb);
      body.appendChild(table);
    };
    this.detail = false;
    await load();
    this.timer = setInterval(load, 5000);
  },

  async generate() {
    toast(t('generating'));
    const draft = await this.call('generate');
    if (draft && typeof draft === 'object') this.residentEditor(draft, true);
  },

  async residentDetail(id) {
    this.detail = true;
    clearInterval(this.timer);
    const d = await this.call('resident', id);
    if (!d) { this.detail = false; return; }
    const top = $('ad-top');
    top.innerHTML = '';
    const body = $('ad-body');
    body.innerHTML = '';
    top.append(
      el('button', { class: 'ghost', text: '← ' + t('back'), onclick: () => { this.detail = false; this.switchTab('residents'); } }),
      el('b', { text: `${d.data.firstname} ${d.data.lastname}` }),
      el('span', { class: 'stat', text: d.row.activityLabel + ' · ' + d.row.location }),
      el('div', { class: 'grow' }),
      el('button', { class: 'small', text: t('btn_teleport'), onclick: () => this.call('teleport', id) }),
      el('button', { class: 'small', text: t('btn_summon'), onclick: () => this.call('summon', id) }));
    const subs = el('div', { class: 'subtabs' });
    const content = el('div');
    body.append(subs, content);
    const views = {
      info: () => this.residentForm(content, d.data, false),
      today: () => this.residentToday(content, d, id),
      rels: () => this.residentRels(content, d, id),
      state: () => this.residentState(content, d, id),
    };
    const btns = {};
    for (const k of Object.keys(views)) {
      btns[k] = el('button', {
        text: t('sub_' + k), onclick: () => {
          Object.values(btns).forEach((b) => b.classList.remove('active'));
          btns[k].classList.add('active');
          content.innerHTML = '';
          views[k]();
        },
      });
      subs.appendChild(btns[k]);
    }
    btns.info.click();
  },

  residentEditor(data, isDraft) {
    this.detail = true;
    clearInterval(this.timer);
    const top = $('ad-top');
    top.innerHTML = '';
    top.append(el('button', { class: 'ghost', text: '← ' + t('back'), onclick: () => { this.detail = false; this.switchTab('residents'); } }),
      el('b', { text: isDraft ? t('draft_title') : t('new_resident') }));
    const body = $('ad-body');
    body.innerHTML = '';
    this.residentForm(body, data || { enabled: true, gender: 'male', age: 30, personality: {}, job: { workdays: [1, 2, 3, 4, 5] } }, true);
  },

  residentForm(root, d, isNew) {
    const p = d.personality || {};
    const j = d.job || {};
    const v = d.vehicle || {};
    const f = {};
    const form = el('div', { class: 'form' });
    f.id = inp(d.id, { disabled: !isNew });
    f.firstname = inp(d.firstname);
    f.lastname = inp(d.lastname);
    f.age = inp(d.age, { type: 'number', min: 16, max: 99 });
    f.gender = sel([{ value: 'male', label: t('gender_male') }, { value: 'female', label: t('gender_female') }], d.gender);
    f.model = inp(d.model);
    f.phone = inp(d.phone_number);
    f.traits = inp((p.traits || []).join(', '));
    f.hobbies = inp((p.hobbies || []).join(', '));
    f.speech = el('textarea', { value: p.speech_style || '' });
    f.values = inp(p.values);
    f.fears = inp(p.fears);
    f.backstory = el('textarea', { value: d.backstory || '' });
    f.backstory.style.minHeight = '90px';
    const tp = d.topics || {};
    const TOPIC_KEYS = ['job', 'work_opinion', 'family', 'origin', 'dream', 'food', 'music', 'secret'];
    f.topics = {};
    for (const k of TOPIC_KEYS) f.topics[k] = el('textarea', { value: tp[k] || '', maxlength: 400, placeholder: t('ph_topic_' + k) });
    f.jobTitle = inp(j.title);
    f.workplace = sel(this.locOptions(true), j.workplaceId || '');
    f.shiftStart = inp(j.shift ? j.shift.start : '', { placeholder: '09:00' });
    f.shiftEnd = inp(j.shift ? j.shift['end'] : '', { placeholder: '17:00' });
    const wd = new Set(j.workdays || []);
    const wdBox = el('div', { class: 'chips' });
    const days = this.boot.weekdays || ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    days.forEach((name, i) => {
      const chip = el('span', { class: 'chip' + (wd.has(i + 1) ? ' on' : ''), text: name });
      chip.addEventListener('click', () => {
        if (wd.has(i + 1)) wd.delete(i + 1); else wd.add(i + 1);
        chip.classList.toggle('on');
      });
      wdBox.appendChild(chip);
    });
    f.home = sel(this.locOptions(false, 'home'), d.homeId);
    f.routine = sel((this.boot.routines || []).map((r) => ({ value: r.id, label: r.label })), d.routine_id);
    f.vModel = inp(v.model, { placeholder: t('vehicle_none') });
    f.vPlate = inp(v.plate, { maxlength: 8 });
    f.vC1 = inp(v.color ? v.color[0] : 0, { type: 'number', min: 0, max: 160 });
    f.vC2 = inp(v.color ? v.color[1] : 0, { type: 'number', min: 0, max: 160 });
    f.vType = sel([{ value: 'automobile', label: t('veh_car') }, { value: 'bike', label: t('veh_bike') }], v.type || 'automobile');
    f.enabled = el('input', { type: 'checkbox', checked: d.enabled !== false });
    f.resetLook = el('input', { type: 'checkbox' });

    const favs = new Set(d.favorite_places || []);
    const favBox = el('div', { class: 'chips' });
    for (const l of this.boot.locations || []) {
      if (l.type === 'home') continue;
      const chip = el('span', { class: 'chip' + (favs.has(l.id) ? ' on' : ''), text: l.label });
      chip.addEventListener('click', () => {
        if (favs.has(l.id)) favs.delete(l.id); else favs.add(l.id);
        chip.classList.toggle('on');
      });
      favBox.appendChild(chip);
    }
    f.acq = inp((d.acquaintances || []).join(', '), { placeholder: 'selin_aksoy, emre_gunes' });

    const modelCheck = el('span', { class: 'muted' });
    const checkModel = async () => {
      const ok = await this.call('validateModel', f.model.value.trim(), true);
      modelCheck.textContent = ok === true ? '✔' : '✖';
    };

    form.append(
      field(t('f_id'), f.id), field(t('f_firstname'), f.firstname), field(t('f_lastname'), f.lastname), field(t('f_age'), f.age),
      field(t('f_gender'), f.gender), field(t('f_model'), el('div', { class: 'inline' }, f.model, el('button', { class: 'small', text: '?', onclick: checkModel }), modelCheck)),
      field(t('f_phone'), f.phone),
      field(t('f_traits'), f.traits, 'span2'), field(t('f_hobbies'), f.hobbies, 'span2'),
      field(t('f_speech'), f.speech, 'span4'),
      field(t('f_values'), f.values, 'span2'), field(t('f_fears'), f.fears, 'span2'),
      field(t('f_backstory'), f.backstory, 'span4'));
    root.appendChild(el('div', { class: 'section-title', text: t('sec_identity') }));
    root.appendChild(form);

    const formT = el('div', { class: 'form' });
    for (const k of Object.keys(f.topics)) formT.append(field(t('f_topic_' + k), f.topics[k], 'span2'));
    root.appendChild(el('div', { class: 'section-title', text: t('sec_topics') }));
    root.appendChild(el('div', { class: 'muted', text: t('topics_help') }));
    root.appendChild(formT);

    const form2 = el('div', { class: 'form' });
    form2.append(
      field(t('f_job'), f.jobTitle), field(t('f_workplace'), f.workplace), field(t('f_shift_start'), f.shiftStart), field(t('f_shift_end'), f.shiftEnd),
      field(t('f_workdays'), wdBox, 'span2'), field(t('f_home'), f.home), field(t('f_routine'), f.routine));
    root.appendChild(el('div', { class: 'section-title', text: t('sec_life') }));
    root.appendChild(form2);

    const form3 = el('div', { class: 'form' });
    form3.append(field(t('f_vmodel'), f.vModel), field(t('f_vplate'), f.vPlate),
      field(t('f_vcolor'), el('div', { class: 'inline' }, f.vC1, f.vC2)), field(t('f_vtype'), f.vType));
    root.appendChild(el('div', { class: 'section-title', text: t('sec_vehicle') }));
    root.appendChild(form3);

    root.appendChild(el('div', { class: 'section-title', text: t('sec_social') }));
    const form4 = el('div', { class: 'form' });
    form4.append(field(t('f_favorites'), favBox, 'span4'), field(t('f_acquaintances'), f.acq, 'span4'),
      field(t('f_enabled'), f.enabled), field(t('f_reset_look'), f.resetLook));
    root.appendChild(form4);

    const save = async () => {
      const payload = {
        id: f.id.value.trim(), firstname: f.firstname.value.trim(), lastname: f.lastname.value.trim(),
        age: num(f.age.value, 30), gender: f.gender.value, model: f.model.value.trim(),
        phone_number: f.phone.value.trim() || undefined,
        personality: {
          traits: f.traits.value.split(',').map((s) => s.trim()).filter(Boolean),
          hobbies: f.hobbies.value.split(',').map((s) => s.trim()).filter(Boolean),
          speech_style: f.speech.value.trim(), values: f.values.value.trim(), fears: f.fears.value.trim(),
        },
        backstory: f.backstory.value.trim(),
        topics: Object.fromEntries(Object.entries(f.topics).map(([k, n]) => [k, n.value.trim()]).filter(([, v]) => v)),
        job: {
          title: f.jobTitle.value.trim(), workplaceId: f.workplace.value || undefined,
          shift: (parseTime(f.shiftStart.value) !== null && parseTime(f.shiftEnd.value) !== null) ? { start: f.shiftStart.value.trim(), end: f.shiftEnd.value.trim() } : undefined,
          workdays: Array.from(wd).sort(),
        },
        homeId: f.home.value, routine_id: f.routine.value,
        vehicle: f.vModel.value.trim() ? { model: f.vModel.value.trim(), plate: f.vPlate.value.trim(), color: [num(f.vC1.value, 0), num(f.vC2.value, 0)], type: f.vType.value } : undefined,
        favorite_places: Array.from(favs),
        acquaintances: f.acq.value.split(',').map((s) => s.trim()).filter(Boolean),
        enabled: f.enabled.checked,
        resetAppearance: f.resetLook.checked,
      };
      if (!payload.id || !/^[a-z0-9_]+$/.test(payload.id)) { toast(t('err_id'), 'bad'); return; }
      const ok = await this.call('saveResident', payload);
      if (ok) {
        toast(t('saved'), 'good');
        await this.refreshBoot();
        this.detail = false;
        this.switchTab('residents');
      }
    };
    const actions = el('div', { class: 'inline' });
    actions.style.marginTop = '18px';
    actions.append(el('button', { class: 'primary', text: t('save'), onclick: save }));
    if (!isNew) {
      actions.append(el('button', {
        class: 'danger', text: t('delete'), onclick: async () => {
          if (!(await confirmModal(t('confirm_delete_resident')))) return;
          if (await this.call('deleteResident', d.id)) {
            toast(t('deleted'), 'good');
            this.detail = false;
            this.switchTab('residents');
          }
        },
      }));
    }
    root.appendChild(actions);
  },

  residentToday(root, d, id) {
    const planBox = el('div', { class: 'plan-list' });
    const dayLabel = el('b');
    let offset = 0;
    const renderPlan = (plan) => {
      planBox.innerHTML = '';
      for (const s of plan) {
        const item = el('div', { class: 'plan-item' },
          el('span', { text: `${s.from} – ${s.to}` }),
          el('span', {}, el('span', { class: 'dot' }), s.activityLabel + (s.flex ? ' *' : '')),
          el('span', { class: 'muted', text: s.locationLabel }));
        item.querySelector('.dot').style.background = ACT_COLORS[s.activity] || '#999';
        planBox.appendChild(item);
      }
    };
    const loadDay = async () => {
      const res = await this.call('previewPlan', { id, offset });
      if (res) { dayLabel.textContent = res.day; renderPlan(res.plan); }
    };
    root.append(el('div', { class: 'section-title', text: t('sec_plan') }),
      el('div', { class: 'inline' },
        el('button', { class: 'small', text: '←', onclick: () => { offset = Math.max(-1, offset - 1); loadDay(); } }),
        dayLabel,
        el('button', { class: 'small', text: '→', onclick: () => { offset = Math.min(6, offset + 1); loadDay(); } }),
        el('span', { class: 'muted', text: t('plan_flex_note') })),
      planBox);
    dayLabel.textContent = t('today');
    renderPlan(d.plan || []);
    const log = el('div', { class: 'log-list' });
    for (const line of d.log || []) log.appendChild(el('div', { text: line }));
    if (!(d.log || []).length) log.appendChild(el('div', { class: 'muted', text: t('empty') }));
    root.append(el('div', { class: 'section-title', text: t('sec_log') }), log);
    if (d.yesterday) root.append(el('div', { class: 'section-title', text: t('sec_yesterday') }), el('div', { class: 'card', text: d.yesterday }));
    const soc = el('div', { class: 'chips' });
    for (const s of d.social || []) soc.appendChild(el('span', { class: 'chip', text: s }));
    root.append(el('div', { class: 'section-title', text: t('sec_ties') }), soc);
    if ((d.appointments || []).length) {
      root.append(el('div', { class: 'section-title', text: t('sec_appointments') }));
      for (const a of d.appointments) root.append(el('div', { class: 'kv' }, el('span', { text: `${a.when} · ${a.place}` }), el('b', { text: `${a.citizenid} (${a.status})` })));
    }
  },

  residentRels(root, d, id) {
    const memBox = el('div');
    const table = el('table', { class: 'grid' });
    table.appendChild(el('thead', {}, el('tr', {},
      ['col_character', 'col_stage', 'col_fam', 'col_aff', 'col_trust', 'col_met', 'col_last', ''].map((k) => el('th', { text: k ? t(k) : '' })))));
    const tb = el('tbody');
    const showMemories = async (cid, name) => {
      memBox.innerHTML = '';
      memBox.append(el('div', { class: 'section-title', text: t('sec_memories', name) }));
      const rows = await this.call('memories', { npcId: id, citizenid: cid });
      if (!rows || !rows.length) { memBox.append(el('div', { class: 'muted', text: t('empty') })); return; }
      for (const m of rows) {
        const imp = el('span', { class: 'imp ' + (m.importance >= 8 ? 'hi' : (m.importance >= 5 ? 'mid' : '')), text: m.importance });
        const row = el('div', { class: 'mem' }, el('span', { class: 'muted', text: m.age }),
          el('span', { text: m.text }), el('span', {}, imp, ' ', el('span', { class: 'muted', text: m.type })),
          el('button', {
            class: 'small danger', text: '✕', onclick: async () => {
              if (await this.call('deleteMemory', m.id)) row.remove();
            },
          }));
        memBox.appendChild(row);
      }
    };
    for (const r of d.relationships || []) {
      tb.appendChild(el('tr', {},
        el('td', {}, el('b', { text: r.name }), el('div', { class: 'muted', text: r.citizenid })),
        el('td', {}, el('span', { class: 'badge stage-' + r.stage, text: r.stageLabel })),
        el('td', { text: r.familiarity }), el('td', { text: r.affinity }), el('td', { text: r.trust }),
        el('td', { text: `${r.timesMet} / ${r.meetDays}${t('days_short')}` }),
        el('td', { class: 'muted', text: r.lastSeen + (r.phoneKnown ? ' 📱' : '') }),
        el('td', {}, el('div', { class: 'row-actions' },
          el('button', { class: 'small', text: t('btn_memories'), onclick: () => showMemories(r.citizenid, r.name) }),
          el('button', {
            class: 'small', text: t('btn_edit'), onclick: async () => {
              const vals = await formModal(t('edit_rel'), [
                { key: 'familiarity', label: t('col_fam'), value: r.familiarity, type: 'number' },
                { key: 'affinity', label: t('col_aff'), value: r.affinity, type: 'number' },
                { key: 'trust', label: t('col_trust'), value: r.trust, type: 'number' },
                { key: 'meet_days', label: t('col_meetdays'), value: r.meetDays, type: 'number' },
              ]);
              if (!vals) return;
              const res = await this.call('setRelationship', { npcId: id, citizenid: r.citizenid, fields: vals });
              if (res) { toast(t('saved'), 'good'); this.residentDetail(id); }
            },
          }),
          el('button', {
            class: 'small danger', text: t('btn_reset'), onclick: async () => {
              if (!(await confirmModal(t('confirm_reset_rel')))) return;
              if (await this.call('resetRelationship', { npcId: id, citizenid: r.citizenid })) { toast(t('done'), 'good'); this.residentDetail(id); }
            },
          })))));
    }
    table.appendChild(tb);
    root.append(table);
    if (!(d.relationships || []).length) root.append(el('div', { class: 'empty', text: t('no_relationships') }));
    root.append(memBox);
    const genBtn = el('button', { class: 'small', text: t('btn_general_memories'), onclick: () => showMemories('', t('general')) });
    root.append(el('div', { class: 'inline' }, genBtn));
  },

  residentState(root, d, id) {
    const r = d.row;
    const cards = el('div', { class: 'cards' });
    const needCard = el('div', { class: 'card' });
    for (const k of ['energy', 'hunger', 'social', 'fun']) {
      const bar = el('div', { class: 'bar' }, el('i'));
      bar.firstChild.style.width = r.needs[k] + '%';
      needCard.append(el('div', { class: 'kv' }, el('span', { text: t('need_' + k) }), el('b', { text: r.needs[k] })), bar);
    }
    cards.append(
      el('div', { class: 'card' },
        el('div', { class: 'kv' }, el('span', { text: t('col_activity') }), el('b', { text: r.activityLabel })),
        el('div', { class: 'kv' }, el('span', { text: t('col_location') }), el('b', { text: r.location })),
        el('div', { class: 'kv' }, el('span', { text: t('layer') }), el('b', { text: r.physical ? t('layer_physical') : t('layer_abstract') })),
        el('div', { class: 'kv' }, el('span', { text: t('col_status') }), el('b', { text: t('status_' + r.status) })),
        el('div', { class: 'kv' }, el('span', { text: t('col_phone') }), el('b', { text: r.phone || '-' }))),
      el('div', { class: 'card' },
        el('div', { class: 'kv' }, el('span', { text: t('col_mood') }), el('b', { text: `${r.mood} (${t('mood_' + r.moodKey)})` })),
        el('div', { class: 'muted', text: r.moodReason })),
      needCard);
    root.append(cards, el('div', { class: 'section-title', text: t('sec_status_actions') }));
    const set = async (status, extra) => {
      if (await this.call('setStatus', Object.assign({ id, status }, extra || {}))) { toast(t('done'), 'good'); this.residentDetail(id); }
    };
    root.append(el('div', { class: 'inline' },
      el('button', { text: t('st_alive'), onclick: () => set('alive') }),
      el('button', { text: t('st_hospital'), onclick: () => set('hospital') }),
      el('button', { text: t('st_jailed'), onclick: () => set('jailed', { days: 1 }) }),
      el('button', { class: 'danger', text: t('st_moved'), onclick: () => set('moved_away') })));
  },

  // ---------------------------------------------------------------- Konumlar
  async locations() {
    const list = await this.call('locations');
    if (!list) return;
    this.locList = list;
    const body = $('ad-body');
    body.innerHTML = '';
    const split = el('div', { class: 'split' });
    const left = el('div', { class: 'list' });
    const right = el('div');
    split.append(left, right);
    body.appendChild(split);
    $('ad-top').append(el('b', { text: t('tab_locations') }), el('div', { class: 'grow' }),
      el('button', { text: t('btn_new_location'), onclick: () => this.locationEditor(right, null) }));
    for (const loc of list) {
      const item = el('div', { class: 'list-item', onclick: () => {
        left.querySelectorAll('.list-item').forEach((x) => x.classList.remove('active'));
        item.classList.add('active');
        this.locationEditor(right, loc);
      } }, loc.label, el('small', { text: `${loc.id} · ${loc.type} · ${loc.points.length} ${t('points')}` }));
      left.appendChild(item);
    }
  },

  coordsRow(label, value, opts) {
    opts = opts || {};
    const c = value || {};
    const x = inp(c.x, { type: 'number', step: '0.01' });
    const y = inp(c.y, { type: 'number', step: '0.01' });
    const z = inp(c.z, { type: 'number', step: '0.01' });
    const w = inp(c.w, { type: 'number', step: '0.1' });
    const row = el('div', { class: 'coords' }, x, y, z, w,
      el('button', {
        class: 'small', text: opts.vehicle ? t('btn_here_vehicle') : t('btn_here'), onclick: async () => {
          const p = await this.call('myPosition', opts.vehicle ? 'vehicle' : 'ped', true);
          if (p) { x.value = p.x; y.value = p.y; z.value = p.z; w.value = p.w; }
        },
      }),
      el('button', { class: 'small', text: '⤴', title: t('btn_teleport'), onclick: () => this.call('teleportCoords', { x: x.value, y: y.value, z: z.value }) }));
    const get = () => (x.value === '' || y.value === '' || z.value === '') ? null : { x: num(x.value, 0), y: num(y.value, 0), z: num(z.value, 0), w: num(w.value, 0) };
    return { node: field(label, row, 'span4'), get };
  },

  locationEditor(root, loc) {
    root.innerHTML = '';
    const isNew = !loc;
    loc = loc || { id: '', label: '', type: 'other', area: '', public: true, door: null, parking: null, points: [], aliases: [] };
    const f = {};
    f.id = inp(loc.id, { disabled: !isNew });
    f.label = inp(loc.label);
    f.type = sel((this.boot.locationTypes || []).map((x) => ({ value: x, label: x })), loc.type);
    f.area = inp(loc.area);
    f.public = el('input', { type: 'checkbox', checked: loc.public !== false });
    f.open = inp(loc.hours ? loc.hours.open : '', { placeholder: '08:00' });
    f.close = inp(loc.hours ? loc.hours.close : '', { placeholder: '22:00' });
    f.aliases = inp((loc.aliases || []).join(', '));
    const door = this.coordsRow(t('f_door'), loc.door);
    const parking = this.coordsRow(t('f_parking'), loc.parking, { vehicle: true });
    const form = el('div', { class: 'form' });
    form.append(field(t('f_id'), f.id), field(t('f_label'), f.label), field(t('f_type'), f.type), field(t('f_area'), f.area),
      field(t('f_public'), f.public), field(t('f_open'), f.open), field(t('f_close'), f.close), field(t('f_aliases'), f.aliases),
      door.node, parking.node);
    root.appendChild(form);

    root.appendChild(el('div', { class: 'section-title', text: t('sec_points') }));
    const pointsBox = el('div');
    root.appendChild(pointsBox);
    const points = [];
    const addPoint = (p) => {
      const coords = this.coordsRow(t('f_coords'), p.coords);
      const scen = sel((this.boot.scenarios || []).map((s) => ({ value: s, label: s })), p.scenario || 'WORLD_HUMAN_STAND_IMPATIENT');
      const tags = new Set(p.tags || []);
      const tagBox = el('div', { class: 'chips' });
      for (const tg of this.boot.tags || []) {
        const chip = el('span', { class: 'chip' + (tags.has(tg) ? ' on' : ''), text: tg });
        chip.addEventListener('click', () => { if (tags.has(tg)) tags.delete(tg); else tags.add(tg); chip.classList.toggle('on'); });
        tagBox.appendChild(chip);
      }
      const entry = { coords, scen, tags };
      const box = el('div', { class: 'point' }, coords.node,
        el('div', { class: 'inline' }, scen,
          el('button', { class: 'small danger', text: t('delete'), onclick: () => { box.remove(); points.splice(points.indexOf(entry), 1); } })),
        tagBox);
      points.push(entry);
      pointsBox.appendChild(box);
    };
    (loc.points || []).forEach(addPoint);
    root.appendChild(el('button', {
      class: 'small', text: t('btn_add_point'), onclick: async () => {
        const pos = await this.call('myPosition', 'ped', true);
        addPoint({ coords: pos || null, tags: ['idle'] });
      },
    }));

    const save = async () => {
      const payload = {
        id: f.id.value.trim(), label: f.label.value.trim(), type: f.type.value, area: f.area.value.trim(),
        public: f.public.checked, door: door.get(), parking: parking.get(),
        hours: (parseTime(f.open.value) !== null && parseTime(f.close.value) !== null) ? { open: f.open.value.trim(), close: f.close.value.trim() } : undefined,
        aliases: f.aliases.value.split(',').map((s) => s.trim()).filter(Boolean),
        points: points.map((p) => ({ coords: p.coords.get(), scenario: p.scen.value, tags: Array.from(p.tags) })).filter((p) => p.coords),
      };
      if (!payload.id || !/^[a-z0-9_]+$/.test(payload.id)) { toast(t('err_id'), 'bad'); return; }
      if (!payload.door) { toast(t('err_door'), 'bad'); return; }
      if (await this.call('saveLocation', payload)) {
        toast(t('saved'), 'good');
        await this.refreshBoot();
        this.switchTab('locations');
      }
    };
    const actions = el('div', { class: 'inline' });
    actions.style.marginTop = '18px';
    actions.append(el('button', { class: 'primary', text: t('save'), onclick: save }));
    if (!isNew) {
      actions.append(el('button', {
        class: 'danger', text: t('delete'), onclick: async () => {
          if (!(await confirmModal(t('confirm_delete_location')))) return;
          if (await this.call('deleteLocation', loc.id)) { toast(t('deleted'), 'good'); await this.refreshBoot(); this.switchTab('locations'); }
        },
      }));
    }
    root.appendChild(actions);
  },

  // ---------------------------------------------------------------- Rutinler
  async routines() {
    const list = await this.call('routines');
    if (!list) return;
    const body = $('ad-body');
    body.innerHTML = '';
    const split = el('div', { class: 'split' });
    const left = el('div', { class: 'list' });
    const right = el('div');
    split.append(left, right);
    body.appendChild(split);
    $('ad-top').append(el('b', { text: t('tab_routines') }), el('div', { class: 'grow' }),
      el('button', { text: t('btn_new_routine'), onclick: () => this.routineEditor(right, null) }));
    for (const rt of list) {
      const item = el('div', { class: 'list-item', onclick: () => {
        left.querySelectorAll('.list-item').forEach((x) => x.classList.remove('active'));
        item.classList.add('active');
        this.routineEditor(right, rt);
      } }, rt.label, el('small', { text: `${rt.id} · ${(rt.users || []).join(', ') || t('unused')}` }));
      left.appendChild(item);
    }
  },

  timeline(blocks, shift) {
    const wrap = el('div');
    const bar = el('div', { class: 'timeline' });
    let prevFrom = -1;
    for (const b of blocks) {
      let f = resolveTok(b.from, shift);
      let to = resolveTok(b.to, shift);
      if (f === null || to === null) continue;
      while (f < prevFrom) f += 1440;
      while (to <= f) to += 1440;
      prevFrom = f;
      const parts = [];
      for (let start = f; start < to;) {
        const dayOff = Math.floor(start / 1440) * 1440;
        const end = Math.min(to, dayOff + 1440);
        parts.push([start - dayOff, end - dayOff]);
        start = end;
      }
      for (const [s, e] of parts) {
        const seg = el('div', { class: 'seg', text: t('act_' + b.activity), title: `${fmtTime(f)}–${fmtTime(to)} ${b.activity} @ ${b.location}` });
        seg.style.left = (s / 1440 * 100) + '%';
        seg.style.width = Math.max(0.4, (e - s) / 1440 * 100) + '%';
        seg.style.background = ACT_COLORS[b.activity] || '#999';
        bar.appendChild(seg);
      }
    }
    const hours = el('div', { class: 'timeline-hours' });
    for (let h = 0; h <= 24; h += 3) hours.appendChild(el('span', { text: String(h).padStart(2, '0') }));
    wrap.append(bar, hours);
    return wrap;
  },

  locationSpecOptions() {
    const out = [
      { value: 'home', label: t('loc_home') }, { value: 'work', label: t('loc_work') },
      { value: 'flex:lunch', label: t('loc_flex_lunch') }, { value: 'flex:free', label: t('loc_flex_free') },
    ];
    for (const ty of this.boot.locationTypes || []) out.push({ value: 'fav:' + ty, label: t('loc_fav', ty) });
    for (const l of this.boot.locations || []) out.push({ value: l.id, label: '📍 ' + l.label });
    return out;
  },

  routineEditor(root, rt) {
    root.innerHTML = '';
    const isNew = !rt;
    rt = rt || { id: '', label: '', workday: [], offday: [] };
    const idIn = inp(rt.id, { disabled: !isNew });
    const labelIn = inp(rt.label);
    const sStart = inp('09:00');
    const sEnd = inp('17:00');
    const form = el('div', { class: 'form' });
    form.append(field(t('f_id'), idIn), field(t('f_label'), labelIn), field(t('f_preview_shift'), el('div', { class: 'inline' }, sStart, sEnd), 'span2'));
    root.append(form, el('div', { class: 'muted', text: t('routine_help') }));
    const sections = {};
    const acts = (this.boot.activities || []).map((a) => ({ value: a.id, label: a.label }));
    const locOpts = this.locationSpecOptions();
    const shift = () => ({ start: sStart.value, end: sEnd.value });

    const makeSection = (key) => {
      const rows = [];
      const box = el('div');
      const tl = el('div');
      const redraw = () => {
        tl.innerHTML = '';
        tl.appendChild(this.timeline(rows.map((r) => r.get()), shift()));
      };
      const addRow = (b) => {
        const from = inp(b.from || '08:00');
        const to = inp(b.to || '12:00');
        const act = sel(acts, b.activity || 'work');
        const loc = sel(locOpts, b.location || 'home');
        const firm = el('input', { type: 'checkbox', checked: !!b.firm, title: 'firm' });
        const roamOn = el('input', { type: 'checkbox', checked: !!b.roam, title: 'roam' });
        const rTypes = inp(b.roam ? (b.roam.types || []).join(', ') : 'shop, cafe, fastfood, park, bar');
        const rSlot = inp(b.roam ? b.roam.slot : 150, { type: 'number' });
        const rAway = inp(b.roam ? b.roam.away : 90, { type: 'number' });
        const rAct = sel(acts, b.roam ? b.roam.activity : 'deliver');
        const roamRow = el('div', { class: 'roam-row' + (b.roam ? '' : ' hidden') }, rTypes, rSlot, rAway, rAct);
        const entry = {
          get: () => {
            const o = { from: from.value.trim(), to: to.value.trim(), activity: act.value, location: loc.value };
            if (firm.checked) o.firm = true;
            if (roamOn.checked) o.roam = { types: rTypes.value.split(',').map((s) => s.trim()).filter(Boolean), slot: num(rSlot.value, 150), away: num(rAway.value, 90), activity: rAct.value };
            return o;
          },
        };
        const row = el('div', { class: 'block-row' }, from, to, act, loc,
          el('label', { class: 'inline' }, firm, 'firm'), el('label', { class: 'inline' }, roamOn, 'roam'),
          el('button', { class: 'small danger', text: '✕', onclick: () => { row.remove(); roamRow.remove(); rows.splice(rows.indexOf(entry), 1); redraw(); } }));
        roamOn.addEventListener('change', () => { roamRow.classList.toggle('hidden', !roamOn.checked); redraw(); });
        [from, to, act, loc, rSlot, rAway].forEach((n) => n.addEventListener('change', redraw));
        rows.push(entry);
        box.append(row, roamRow);
      };
      (rt[key] || []).forEach(addRow);
      const sec = el('div', {}, el('div', { class: 'section-title', text: t('sec_' + key) }), tl, box,
        el('button', { class: 'small', text: t('btn_add_block'), onclick: () => { addRow({}); redraw(); } }));
      root.appendChild(sec);
      sections[key] = { rows, redraw };
      redraw();
    };
    makeSection('workday');
    makeSection('offday');
    [sStart, sEnd].forEach((n) => n.addEventListener('change', () => { sections.workday.redraw(); sections.offday.redraw(); }));

    const actions = el('div', { class: 'inline' });
    actions.style.marginTop = '18px';
    actions.append(el('button', {
      class: 'primary', text: t('save'), onclick: async () => {
        const payload = {
          id: idIn.value.trim(), label: labelIn.value.trim(),
          workday: sections.workday.rows.map((r) => r.get()), offday: sections.offday.rows.map((r) => r.get()),
        };
        if (!payload.id || !/^[a-z0-9_]+$/.test(payload.id)) { toast(t('err_id'), 'bad'); return; }
        if (await this.call('saveRoutine', payload)) { toast(t('saved'), 'good'); await this.refreshBoot(); this.switchTab('routines'); }
      },
    }));
    if (!isNew) {
      actions.append(el('button', {
        class: 'danger', text: t('delete'), onclick: async () => {
          if (!(await confirmModal(t('confirm_delete_routine')))) return;
          if (await this.call('deleteRoutine', rt.id)) { toast(t('deleted'), 'good'); await this.refreshBoot(); this.switchTab('routines'); }
        },
      }));
    }
    root.appendChild(actions);
  },

  // ---------------------------------------------------------------- Diyalog testi
  // Sunucudaki kural tabanlı motoru yan etkisiz çalıştırır: hangi niyet seçildi, puanlar, yakalanan bilgiler, cevap
  async dialogue() {
    const residents = await this.call('overview', null, true);
    const list = (residents && residents.residents) || [];
    const top = $('ad-top');
    top.append(el('b', { text: t('tab_dialogue') }), el('div', { class: 'grow' }), el('span', { class: 'muted', text: t('dlg_help') }));
    const body = $('ad-body');
    const who = sel(list.map((r) => ({ value: r.id, label: `${r.name} (${r.job})` })), this.dlgWho || (list[0] && list[0].id));
    const stages = ['stranger', 'acquaintance', 'friend', 'close_friend', 'cold', 'enemy'];
    const stage = sel(stages.map((s) => ({ value: s, label: t('stage_' + s) })), this.dlgStage || 'stranger');
    const text = inp('', { maxlength: 300, placeholder: t('dlg_placeholder') });
    const out = el('div');
    const hist = el('div', { class: 'dlg-history' });
    // aynı sakin + aşamada bağlam (son konu, bekleyen soru) denemeler arasında korunur
    let resetNext = true;
    const reset = () => { resetNext = true; out.innerHTML = ''; hist.innerHTML = ''; };
    who.addEventListener('change', reset);
    stage.addEventListener('change', reset);
    const run = async () => {
      const v = text.value.trim();
      if (!v || !who.value) return;
      this.dlgWho = who.value;
      this.dlgStage = stage.value;
      const r = await this.call('testDialogue', { id: who.value, stage: stage.value, text: v, reset: resetNext });
      resetNext = false;
      text.value = '';
      if (!r) return;
      out.innerHTML = '';
      const maxScore = Math.max(1, ...(r.top || []).map((x) => x.score));
      const scores = el('div', {}, ...(r.top || []).map((x) => {
        const b = el('div', { class: 'bar' }, el('i'));
        b.firstChild.style.width = clamp(x.score / maxScore * 100, 0, 100) + '%';
        return el('div', { class: 'score-row' }, el('span', { text: x.id }), b, el('b', { text: String(x.score) }));
      }));
      const slots = Object.entries(r.slots || {}).filter(([, val]) => val !== undefined && val !== null && val !== '');
      out.append(
        el('div', { class: 'card' },
          el('div', { class: 'kv' }, el('span', { text: t('dlg_intent') }), el('b', { text: r.intent || t('dlg_fallback') })),
          el('div', { class: 'kv' }, el('span', { text: t('dlg_emotion') }), el('b', { text: t('emotion_' + (r.emotion || 'neutral')) })),
          el('div', { class: 'kv' }, el('span', { text: t('dlg_delta') }), el('b', { text: `${t('rel_affinity')} ${r.dAff >= 0 ? '+' : ''}${r.dAff || 0} · ${t('rel_trust')} ${r.dTrust >= 0 ? '+' : ''}${r.dTrust || 0}` })),
          (r.actions || []).length ? el('div', { class: 'kv' }, el('span', { text: t('dlg_actions') }), el('b', { text: r.actions.map((a) => a.type).join(', ') })) : null),
        el('div', { class: 'section-title', text: t('dlg_reply') }),
        el('div', { class: 'dlg-reply', text: r.reply || '—' }),
        el('div', { class: 'section-title', text: t('dlg_scores') }),
        scores,
        el('div', { class: 'section-title', text: t('dlg_slots') }),
        slots.length ? el('div', {}, ...slots.map(([k, val]) => el('div', { class: 'kv' }, el('span', { text: k }), el('b', { text: String(val) }))))
          : el('div', { class: 'muted', text: '—' }));
      const item = el('div', { class: 'card', onclick: () => { text.value = v; run(); } },
        el('div', { class: 'muted', text: `${r.intent || t('dlg_fallback')} · ${t('stage_' + stage.value)}` }), el('div', { text: v }));
      hist.prepend(item);
      while (hist.children.length > 12) hist.lastChild.remove();
    };
    text.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); run(); } });
    const form = el('div', { class: 'form' });
    form.append(field(t('dlg_resident'), who, 'span2'), field(t('dlg_stage'), stage),
      field('', el('div', { class: 'inline' }, el('button', { class: 'primary', text: t('dlg_run'), onclick: run }), el('button', { text: t('dlg_reset'), onclick: reset }))),
      field(t('dlg_text'), text, 'span4'));
    body.append(form, el('div', { class: 'dlg-test' }, el('div', {}, out), el('div', {}, el('div', { class: 'section-title', text: t('dlg_history') }), hist)));
    setTimeout(() => text.focus(), 30);
  },
};

document.querySelectorAll('.tab-btn').forEach((b) => b.addEventListener('click', () => { Admin.detail = false; Admin.switchTab(b.dataset.tab); }));
$('ad-close').addEventListener('click', () => Admin.close());

// ------------------------------------------------------------------ mesajlar & klavye
window.addEventListener('message', (e) => {
  const d = e.data || {};
  switch (d.action) {
    case 'convo:open': Convo.show(d.data); break;
    case 'convo:message': Convo.npcMessage(d.data || {}); break;
    case 'convo:thinking': Convo.thinking(d.value); break;
    case 'convo:error': Convo.thinking(false); Convo.system(d.text, 'bad'); break;
    case 'convo:ended': Convo.system(d.text, 'warn'); Convo.lock(); break;
    case 'convo:close': Convo.close(); break;
    case 'convo:focus': Convo.setFocus(d.value); break;
    case 'bubble:set': Bubbles.set(d.id, d.text, d.kind); break;
    case 'bubble:remove': Bubbles.remove(d.id); break;
    case 'bubble:pos': Bubbles.pos(d.list); break;
    case 'phone:open': Phone.show(d.contacts); break;
    case 'phone:message': Phone.incoming(d.message || {}); break;
    case 'phone:typing': Phone.typing(d.npcId, d.value); break;
    case 'admin:open': Admin.show(d.bootstrap); break;
    default: break;
  }
});

window.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape') return;
  const modal = document.querySelector('.modal-back');
  if (modal) { modal.remove(); return; }
  if (Admin.open) { Admin.close(); return; }
  if (Phone.open) { Phone.close(); return; }
  if (Convo.open) Convo.end();
});

// ------------------------------------------------------------------ tarayıcı önizlemesi (oyun dışı)
const DevMock = {
  handle(name, data) {
    if (name === 'ui:ready') {
      return { strings: {}, maxChars: 300, focusKey: 'Y' };
    }
    if (name === 'admin') {
      const a = data && data.action;
      if (a === 'bootstrap') return { ok: true, data: DevMock.boot };
      if (a === 'overview') return { ok: true, data: DevMock.overview() };
      if (a === 'testDialogue') return { ok: true, data: { intent: 'ask_job', reply: 'Oto tamircisiyim. İş yerim Benny\'s Motorworks. Sen ne iş yapıyorsun?', emotion: 'neutral', dAff: 0, dTrust: 1, actions: [], top: [{ id: 'ask_job', score: 3.5 }, { id: 'ask_doing', score: 1.2 }, { id: 'greet', score: 0.5 }], slots: { place: "Benny's Motorworks" } } };
      if (a === 'routines') return { ok: true, data: [{ id: 'day_worker', label: 'Gündüz çalışanı', users: ['Murat', 'Can'], workday: [{ from: 'shift_start-150', to: 'shift_start', activity: 'home_idle', location: 'home' }, { from: 'shift_start', to: 'shift_mid', activity: 'work', location: 'work' }, { from: 'shift_mid', to: 'shift_mid+60', activity: 'lunch', location: 'flex:lunch' }, { from: 'shift_mid+60', to: 'shift_end', activity: 'work', location: 'work' }, { from: 'shift_end', to: 'shift_end+240', activity: 'free', location: 'flex:free' }, { from: 'shift_end+270', to: 'shift_start-150', activity: 'sleep', location: 'home' }], offday: [{ from: '09:30', to: '12:00', activity: 'home_idle', location: 'home' }, { from: '12:00', to: '23:00', activity: 'free', location: 'flex:free' }, { from: '23:30', to: '09:30', activity: 'sleep', location: 'home' }] }] };
      if (a === 'locations') return { ok: true, data: [{ id: 'benny', label: "Benny's Motorworks", type: 'garage', area: 'strawberry', public: true, door: { x: -205.6, y: -1310.4, z: 31.29, w: 180 }, parking: null, points: [{ coords: { x: -212, y: -1325, z: 30.89, w: 0 }, scenario: 'WORLD_HUMAN_WELDING', tags: ['work'] }], aliases: ['benny'] }] };
      return { ok: true, data: true };
    }
    return { ok: true };
  },
  boot: {
    locations: [{ id: 'benny', label: "Benny's Motorworks", type: 'garage' }, { id: 'house_forum_dr', label: 'Forum Drive Evi', type: 'home' }],
    routines: [{ id: 'day_worker', label: 'Gündüz çalışanı' }],
    activities: [{ id: 'work', label: 'çalışıyor' }, { id: 'sleep', label: 'uyuyor' }, { id: 'home_idle', label: 'evde' }, { id: 'lunch', label: 'öğle arası' }, { id: 'free', label: 'boş zaman' }, { id: 'deliver', label: 'teslimat' }],
    scenarios: ['WORLD_HUMAN_STAND_IMPATIENT', 'WORLD_HUMAN_WELDING'], locationTypes: ['home', 'work', 'cafe', 'bar', 'garage'],
    tags: ['work', 'idle', 'smoke'], weekdays: ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'],
  },
  overview() {
    return {
      clock: 'Salı 14:32', weather: 'açık', spawned: 3, maxSpawned: 20, appointments: 1,
      residents: [
        { id: 'murat_demir', name: 'Murat Demir', job: 'Oto tamircisi', enabled: true, status: 'alive', activity: 'work', activityLabel: 'çalışıyor', location: "Benny's Motorworks", physical: true, moodKey: 'good', moodReason: 'keyfi yerinde', needs: { energy: 62, hunger: 48, social: 55, fun: 30 } },
        { id: 'elif_kaya', name: 'Elif Kaya', job: 'Garson', enabled: true, status: 'alive', activity: 'commute', activityLabel: 'yolda', location: 'South Rockford → Tequi-la-la', physical: false, moodKey: 'neutral', moodReason: 'idare eder', needs: { energy: 80, hunger: 20, social: 70, fun: 60 } },
        { id: 'zeynep_arslan', name: 'Zeynep Arslan', job: 'Hemşire', enabled: true, status: 'alive', activity: 'sleep', activityLabel: 'uyuyor', location: 'Integrity Way', physical: false, inside: true, moodKey: 'bad', moodReason: 'çok yorgun', needs: { energy: 18, hunger: 40, social: 35, fun: 40 } },
      ],
    };
  },
};

// ------------------------------------------------------------------ başlangıç
(async () => {
  const res = await post('ui:ready', {});
  if (res) {
    T = res.strings || {};
    CFG = Object.assign(CFG, res);
  }
  applyStaticStrings();
  if (!IN_GAME) {
    document.body.style.background = 'linear-gradient(135deg,#3b4a5e,#1c2430)';
    Convo.show({ name: 'Murat Demir', subtitle: 'Oto tamircisi', stage: 'acquaintance', stageLabel: 'Tanıdık', mood: 'good', rel: { familiarity: 34, affinity: 22, trust: 28 }, text: 'Ooo, sen misin? Hoş geldin. Ne var ne yok?', suggestions: ['Nasılsın?', 'Ne yapıyorsun?', 'Numaranı alabilir miyim?', 'Beni hatırlıyor musun?', 'Görüşürüz'] });
    Convo.addMsg('player', 'İyiyim usta, arabanın motoru tekliyor, bakabilir misin?');
    Convo.npcMessage({ text: 'Getir yarın sabah, bir bakarız. Bujiler gitmiştir büyük ihtimal.', emotion: 'happy', name: 'Murat Demir', stage: 'acquaintance', stageLabel: 'Tanıdık', mood: 'good', rel: { familiarity: 36, affinity: 24, trust: 29 }, ui: [{ text: '📱 Murat numarasını verdi: 55512345' }] });
    Bubbles.set('n1', 'Getir yarın sabah, bir bakarız.', 'npc');
    Bubbles.set('p1', 'Tamam usta!', 'player');
    Bubbles.set('t1', '...', 'thinking');
    Bubbles.pos([{ id: 'n1', x: 0.3, y: 0.3, s: 1, v: true }, { id: 'p1', x: 0.62, y: 0.34, s: 0.85, v: true }, { id: 't1', x: 0.8, y: 0.25, s: 0.7, v: true }]);
    const bar = el('div', {}, el('button', { text: 'Admin', onclick: () => Admin.show(DevMock.boot) }), ' ',
      el('button', { text: 'Telefon', onclick: () => Phone.show([{ npcId: 'x', name: 'Elif Kaya', number: '55512345', lastText: 'Yarın 20:00 plajda!' }]) }));
    bar.style.cssText = 'position:fixed;top:10px;left:10px;z-index:100';
    document.body.appendChild(bar);
  }
})();
