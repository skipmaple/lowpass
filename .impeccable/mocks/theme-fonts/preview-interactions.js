// Design-preview data only: no production requests or writes.
const theme = document.body.dataset.theme;
const scene = document.body.dataset.scene;
const stateKey = 'lowpass-preview-bookmarks-v1';
const searchKey = 'lowpass-preview-search-v1';
const labels = { uv: 'uv', astra: '让模型直接读写另一个模型的权重' };
let saved = { uv: true, astra: false };
try { saved = { ...saved, ...JSON.parse(localStorage.getItem(stateKey) || '{}') }; } catch {}
const status = document.createElement('span');
status.className = 'preview-status';
status.setAttribute('role', 'status');
status.setAttribute('aria-atomic', 'true');
document.body.append(status);
const feedback = document.createElement('div');
feedback.className = 'preview-feedback';
feedback.hidden = true;
const feedbackText = document.createElement('span');
const undo = document.createElement('button');
undo.type = 'button';
undo.textContent = '撤销';
feedback.append(feedbackText, undo);
let undoAction;
let feedbackTimer;
let feedbackOwner;
let renderSearch = () => {};
let libraryView;

function dismissFeedback() {
  clearTimeout(feedbackTimer);
  if (feedback.contains(document.activeElement)) {
    if (feedbackOwner?.checkVisibility()) feedbackOwner.focus();
    else {
      const input = document.querySelector('input[type="search"]');
      if (input?.checkVisibility()) input.focus();
      else document.querySelector('[data-module-title]')?.focus();
    }
  }
  feedback.hidden = true;
  undoAction = null;
}
function scheduleFeedback(duration = feedback.hasAttribute('data-undone') ? 2000 : 8000) {
  clearTimeout(feedbackTimer);
  feedbackTimer = setTimeout(() => {
    if (!feedback.hasAttribute('data-undone') && (feedback.matches(':hover') || feedback.contains(document.activeElement))) return;
    dismissFeedback();
  }, duration);
}
feedback.addEventListener('pointerenter', () => { if (!feedback.hasAttribute('data-undone')) clearTimeout(feedbackTimer); });
feedback.addEventListener('pointerleave', () => scheduleFeedback());
feedback.addEventListener('focusin', () => { if (!feedback.hasAttribute('data-undone')) clearTimeout(feedbackTimer); });
feedback.addEventListener('focusout', () => scheduleFeedback());
feedback.addEventListener('keydown', event => { if (event.key === 'Escape') dismissFeedback(); });
undo.addEventListener('click', () => undoAction?.());

function renderBookmarks() {
  document.querySelectorAll('.bookmark-control[data-bookmark]').forEach(control => {
    const active = !!saved[control.dataset.bookmark];
    control.setAttribute('aria-pressed', String(active));
    control.setAttribute('aria-label', `${active ? '取消收藏' : '收藏'}：${labels[control.dataset.bookmark]}`);
    control.querySelector('.bookmark-text').textContent = active ? '已收藏' : '收藏';
  });
  renderSearch();
}
function setSaved(id, value) {
  saved[id] = value;
  try { localStorage.setItem(stateKey, JSON.stringify(saved)); } catch {}
  renderBookmarks();
}
function placeFeedback(control) {
  const detached = !control.checkVisibility();
  feedback.classList.toggle('detached', detached);
  if (detached) document.body.append(feedback);
  else control.closest('.bookmark-slot').append(feedback);
}
function changeBookmark(control) {
  dismissFeedback();
  feedbackOwner = control;
  const id = control.dataset.bookmark;
  const previous = !!saved[id];
  const active = !previous;
  const label = labels[id];
  setSaved(id, active);
  placeFeedback(control);
  feedback.removeAttribute('data-undone');
  feedback.hidden = false;
  undo.hidden = false;
  undo.setAttribute('aria-label', `撤销${active ? '收藏' : '取消收藏'}：${label}`);
  const message = active ? `已收藏「${label}」，可在收藏中找回。` : `已取消「${label}」的收藏。`;
  feedbackText.textContent = message;
  status.textContent = message;
  undoAction = () => {
    clearTimeout(feedbackTimer);
    setSaved(id, previous);
    placeFeedback(control);
    status.textContent = previous ? `已恢复「${label}」的收藏。` : `已撤销「${label}」的收藏。`;
    feedbackText.textContent = '已撤销';
    feedback.setAttribute('data-undone', '');
    undo.hidden = true;
    undoAction = null;
    if (control.checkVisibility()) control.focus({ preventScroll: true });
    // This acknowledgement is brief; the button remains the durable state.
    feedbackTimer = setTimeout(dismissFeedback, 2000);
  };
  if (!control.checkVisibility()) undo.focus({ preventScroll: true });
  scheduleFeedback();
}
document.querySelectorAll('.bookmark-control[data-bookmark]').forEach(control => {
  control.addEventListener('click', () => changeBookmark(control));
});
window.addEventListener('storage', event => {
  if (event.key !== stateKey) return;
  try { saved = { uv: true, astra: false, ...JSON.parse(event.newValue || '{}') }; } catch { return; }
  dismissFeedback();
  renderBookmarks();
});
renderBookmarks();

if (scene === 'library') {
  let cached = {};
  try { cached = JSON.parse(sessionStorage.getItem(searchKey) || '{}') || {}; } catch {}
  const requestedView = new URLSearchParams(location.search).get('view');
  libraryView = ['saved', 'search'].includes(requestedView)
    ? requestedView : cached.view === 'search' ? 'search' : 'saved';
  const isSearch = libraryView === 'search';
  document.body.dataset.module = libraryView;
  const moduleTitle = isSearch ? '搜索' : '收藏';
  const heading = document.querySelector('[data-module-title]');
  heading.textContent = moduleTitle;
  document.title = `Lowpass · ${{ daybreak: '层叠清晨', duet: '双声部', unfold: '展开阅读' }[theme]} · ${moduleTitle}`;
  const description = document.createElement('p');
  description.className = 'module-description';
  description.textContent = isSearch ? '找回读过的内容，也找到新的线索。' : '留下有用的发现，日后接着用。';
  if (theme === 'unfold') document.querySelector('.index').append(description);
  else heading.after(description);
  document.querySelector('.module-content')?.setAttribute('aria-label', `${moduleTitle}内容`);
  document.querySelector('[data-search-panel]').hidden = false;
  document.querySelectorAll('[data-module-link]').forEach(link => {
    const active = link.dataset.moduleLink === libraryView;
    link.classList.toggle({ daybreak: 'current', duet: 'selected', unfold: 'active' }[theme], active);
    if (active) link.setAttribute('aria-current', 'page');
    else link.removeAttribute('aria-current');
  });
  // The preview shell reloads the same template when changing themes. Remember
  // the destination, while explicit navigation always names its own module.
  const moduleUrl = new URL(location.href);
  moduleUrl.searchParams.set('view', libraryView);
  history.replaceState(null, '', moduleUrl);
  const input = document.querySelector('input');
  const searchbox = input.closest('.search, .searchbox, .searchbar');
  const items = [
    { node: document.querySelector('[data-entry="uv"]'), id: 'uv', text: 'uv astral-sh Rust Python 环境 依赖 包 项目 管理 工具 工作区 脚本 GitHub Trending' },
    { node: document.querySelector('[data-entry="astra"]'), id: 'astra', text: '让模型直接读写另一个模型的权重 Astra Qwen 实验 推理循环 定位 检查 修改 早期结果 通用训练 替代方案 研究 控制策略 Hacker News rikiyat.github.io' },
  ];
  let query = '';
  // Earlier previews kept only the global-search query. Do not import it as a
  // collection filter: each destination remembers its own search independently.
  const queries = {
    search: typeof cached.queries?.search === 'string' ? cached.queries.search : typeof cached.query === 'string' ? cached.query : '',
    saved: typeof cached.queries?.saved === 'string' ? cached.queries.saved : '',
  };
  input.value = queries[libraryView];
  input.type = 'search';
  input.placeholder = '标题、用途或项目名';
  input.setAttribute('aria-label', isSearch ? '搜索全部内容的标题、用途或项目名' : '搜索收藏');
  searchbox.setAttribute('aria-label', isSearch ? '搜索全部内容' : '搜索收藏');
  if (!isSearch) {
    input.id = 'collection-query';
    const label = document.createElement('label');
    label.className = 'collection-search-label';
    label.htmlFor = input.id;
    label.textContent = '搜索收藏';
    searchbox.before(label);
  }
  searchbox.querySelector('button').removeAttribute('title');
  const summary = document.createElement('div');
  summary.className = 'search-summary';
  const count = document.createElement('span');
  count.setAttribute('role', 'status');
  const reset = document.createElement('button');
  reset.type = 'button';
  reset.textContent = '清除搜索';
  summary.append(count, reset);
  items[0].node.before(summary);
  const empty = document.createElement('section');
  empty.className = 'search-empty';
  empty.hidden = true;
  empty.innerHTML = '<h2></h2><p></p><div class="search-examples"><span>试试</span><button type="button" data-query="uv">uv</button><button type="button" data-query="模型">模型</button></div><button class="empty-reset" type="button">清除搜索</button><a href="'+theme+'.html">去读日刊</a>';
  summary.after(empty);
  const clear = () => { dismissFeedback(); input.value = ''; renderSearch(); input.focus(); };
  const search = () => { dismissFeedback(); renderSearch(); };
  reset.addEventListener('click', clear);
  empty.querySelector('.empty-reset').addEventListener('click', clear);
  empty.querySelectorAll('[data-query]').forEach(button => button.addEventListener('click', () => {
    input.value = button.dataset.query;
    search();
    input.focus({ preventScroll: true });
  }));
  input.addEventListener('keydown', event => {
    if (event.key === 'Enter') { event.preventDefault(); search(); }
    if (event.key === 'Escape') { event.preventDefault(); clear(); }
  });
  input.addEventListener('search', search);
  if (!isSearch) {
    input.addEventListener('input', event => { if (!event.isComposing) search(); });
    input.addEventListener('compositionend', search);
  }
  searchbox.addEventListener('submit', event => { event.preventDefault(); search(); });
  renderSearch = () => {
    query = input.value.trim();
    const terms = query.toLocaleLowerCase().split(/\s+/).filter(Boolean);
    const savedCount = items.filter(item => saved[item.id]).length;
    let matches = 0;
    items.forEach(item => {
      const visible = isSearch
        ? query.length > 0 && terms.every(term => item.text.toLocaleLowerCase().includes(term))
        : !!saved[item.id] && terms.every(term => item.text.toLocaleLowerCase().includes(term));
      item.node.hidden = !visible;
      if (visible) matches += 1;
    });
    count.textContent = isSearch ? `找到 ${matches} 条内容`
      : query ? `找到 ${matches} 条收藏，共 ${savedCount} 条` : `已保存 ${savedCount} 条内容`;
    summary.hidden = isSearch && !query;
    reset.hidden = !query || matches === 0;
    empty.hidden = matches > 0;
    const noSavedItems = !isSearch && savedCount === 0;
    const startingSearch = isSearch && !query;
    empty.querySelector('h2').textContent = noSavedItems ? '还没有收藏内容'
      : startingSearch ? '从一个关键词开始'
      : isSearch ? `没有找到「${query}」` : `收藏中没有找到「${query}」`;
    empty.querySelector('p').textContent = noSavedItems
      ? '读到以后还想用的内容，点一下收藏，就能在这里找回。'
      : startingSearch ? '记得项目名，或只记得它解决的问题，都可以试着找找。'
      : isSearch ? '换一个更短的关键词，或试试项目名、技术名。'
      : '试试更短的关键词，或清除搜索查看全部收藏。';
    empty.querySelector('.search-examples').hidden = !startingSearch;
    empty.querySelector('.empty-reset').hidden = !query;
    empty.querySelector('a').hidden = !noSavedItems;
    queries[libraryView] = query;
    try { sessionStorage.setItem(searchKey, JSON.stringify({ query, queries, scope: isSearch ? 'all' : 'saved', view: libraryView })); } catch {}
  };
  renderSearch();
  if (isSearch && location.hash === '#search') input.focus();
}

// Keep unsupported preview routes visibly unavailable rather than inert.
document.querySelectorAll('button').forEach(button => {
  const text = button.textContent.trim();
  const label = button.getAttribute('aria-label') || '';
  if (text === '周刊' || /前一期|后一期|上一期|下一期/.test(label) || ['刊物', '生成设置', '用户', '任务', '编辑', '新增来源'].some(name => text.replace(/[＋+]/g, '').trim().replace(/^0\d\s*/, '') === name)) {
    button.disabled = true;
    button.title = '本设计样刊未展开此页面';
  }
});
if (scene === 'daily' && (theme === 'daybreak' || theme === 'duet')) {
  const controls = [...document.querySelectorAll('.sources a[href^="#"], .sources button[data-source]')];
  const sourceId = control => control.dataset.source || control.getAttribute('href').slice(1);
  const markCurrentSource = (requested = location.hash.slice(1)) => {
    const current = controls.some(control => sourceId(control) === requested) ? requested : 'hacker-news';
    controls.forEach(control => {
      const active = sourceId(control) === current;
      control.classList.toggle(theme === 'daybreak' ? 'current' : 'active', active);
      if (active) control.setAttribute('aria-current', 'location');
      else control.removeAttribute('aria-current');
    });
  };
  controls.forEach(control => control.addEventListener('click', () => {
    const id = sourceId(control);
    if (control.tagName === 'BUTTON') {
      location.hash = id;
      document.getElementById(id)?.scrollIntoView({ block: 'start' });
    }
    markCurrentSource(id);
  }));
  window.addEventListener('hashchange', () => markCurrentSource());
  markCurrentSource();
}

// A small disclosure makes account navigation identical across all themes.
document.querySelectorAll('button.account').forEach(button => {
  const wrap = document.createElement('div');
  wrap.className = 'preview-account';
  button.before(wrap);
  wrap.append(button);
  const menu = document.createElement('div');
  menu.className = 'preview-account-menu';
  menu.id = 'preview-account-menu';
  menu.hidden = true;
  const link = document.createElement('a');
  link.href = `${theme}${scene === 'admin' ? '' : '-admin'}.html`;
  link.textContent = scene === 'admin' ? '返回日刊' : '管理';
  menu.append(link);
  wrap.append(menu);
  button.setAttribute('aria-expanded', 'false');
  button.setAttribute('aria-controls', menu.id);
  button.addEventListener('click', () => { menu.hidden = !menu.hidden; button.setAttribute('aria-expanded', String(!menu.hidden)); });
});
function closeAccounts(event) {
  document.querySelectorAll('.preview-account').forEach(wrap => {
    if (event.type === 'keydown' || !wrap.contains(event.target)) {
      const button = wrap.querySelector('button');
      if (event.type === 'keydown' && button.getAttribute('aria-expanded') === 'true') button.focus();
      wrap.querySelector('.preview-account-menu').hidden = true;
      button.setAttribute('aria-expanded', 'false');
    }
  });
  document.querySelectorAll('details.account[open]').forEach(menu => {
    if (event.type === 'keydown' || !menu.contains(event.target)) {
      menu.open = false;
      if (event.type === 'keydown') menu.querySelector('summary').focus();
    }
  });
}
document.addEventListener('keydown', event => { if (event.key === 'Escape') closeAccounts(event); });
document.addEventListener('click', closeAccounts);
document.querySelectorAll('a[aria-disabled="true"]').forEach(link => link.addEventListener('click', event => event.preventDefault()));

if (scene === 'admin') {
  const records = document.createElement('section');
  records.className = 'preview-records';
  records.hidden = true;
  records.innerHTML = '<div class="record-heading"><h2 tabindex="-1"></h2><button type="button">收起记录</button></div><dl></dl><p class="record-help"></p>';
  document.querySelector('.notice').after(records);
  let opener;
  document.querySelectorAll('button').forEach(button => {
    if (/查看记录|抓取记录/.test(button.textContent)) {
      button.removeAttribute('title');
      button.setAttribute('aria-expanded', 'false');
      button.addEventListener('click', () => {
        document.querySelectorAll('[aria-expanded="true"]').forEach(other => { if (other !== button && /记录/.test(other.textContent)) other.setAttribute('aria-expanded', 'false'); });
        opener = button;
        const row = button.closest('tr, .source-row');
        const source = row ? row.querySelector('td, h2').textContent.trim() : 'Hackaday';
        const failed = source === 'Hackaday';
        records.querySelector('h2').textContent = `${source} · 抓取记录`;
        const values = [['抓取时间', source === '阮一峰周刊' ? '2026.11.01 06:00' : '2026.11.04 06:00'], ['结果', failed ? '请求失败' : '正常'], ['本期影响', failed ? '本来源暂缺，其余来源正常出刊。' : '已收录到本期。']];
        const list = records.querySelector('dl');
        list.replaceChildren();
        values.forEach(([term, value]) => { const dt = document.createElement('dt'); const dd = document.createElement('dd'); dt.textContent = term; dd.textContent = value; list.append(dt, dd); });
        records.querySelector('.record-help').textContent = failed
          ? '失败详情未提供。来源恢复后，可在刊物管理中按期重抓本来源；替换会记录修订时间。此处为样例记录。'
          : '日期与状态为样例记录。已发布刊期保持固定；推荐理由与译文可以后补。';
        records.hidden = false;
        button.setAttribute('aria-expanded', 'true');
        records.scrollIntoView({ block: 'nearest' });
        records.querySelector('h2').focus({ preventScroll: true });
      });
    }
  });
  function closeRecords() {
    if (!records.hidden) { records.hidden = true; opener?.setAttribute('aria-expanded', 'false'); opener?.focus(); }
  }
  records.querySelector('button').addEventListener('click', closeRecords);
  records.addEventListener('keydown', event => { if (event.key === 'Escape') closeRecords(); });
}

const help = document.createElement('details');
help.className = 'preview-help';
const helpSummary = document.createElement('summary');
const helpCopy = document.createElement('p');
helpSummary.textContent = scene === 'admin' ? '状态说明' : '设计样刊说明';
helpCopy.textContent = scene === 'daily'
  ? '按来源顺序阅读。中文简述解释内容，「值得关注」指出原文中的具体价值；原文入口供继续核对。收藏后可在收藏页找回。本样刊仅展示部分条目，周刊与历史期暂未展开。Subvocal 仅提供了标题，未提供正文或原文地址，因此未展示原文与收藏操作；这不是正式条目的缺理由规则。'
  : scene === 'library'
    ? libraryView === 'search'
      ? '搜索覆盖本样刊的两条完整示例，可按标题、用途或项目名查找；按 Enter 搜索、Esc 清除。收藏与搜索是独立入口，搜索词与收藏状态在三套主题间保留。'
      : '这里只展示已保存的内容，可按标题、用途或项目名即时搜索；清除搜索会恢复全部收藏。需要查找未收藏的内容时，使用导航中的「搜索」。两个页面分别保留关键词；收藏状态在三套主题间共享，取消后可撤销。'
    : '一个来源失败不会阻止其他来源出刊。查看记录可了解影响；所有时间按 Asia/Shanghai 展示。本样刊可查看记录，编辑与新增页面暂未展开。';
if (scene !== 'admin') {
  helpSummary.insertAdjacentHTML('beforeend', '<svg class="ui-icon icon-chevron" viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6"/></svg>');
}
help.append(helpSummary, helpCopy);
// Library details unfold within their record; B keeps its second voice on desktop.
const recordMedia = matchMedia('(min-width: 961px)');
const recordDetails = [...document.querySelectorAll('[data-desktop-open]')];
const syncRecordPresentation = () => recordDetails.forEach(details => { details.open = recordMedia.matches; });
syncRecordPresentation();
recordMedia.addEventListener('change', syncRecordPresentation);
document.querySelector('main').append(help);

// In a single reading column, reveal evidence on request without losing it.
if (theme === 'unfold' && matchMedia('(max-width: 1100px)').matches) {
  document.querySelectorAll('details.evidence, details.source').forEach(details => { details.open = false; });
}

// Theme is a view preference; the current module, query and saved items stay shared.
const themes = [['daybreak', 'A · 层叠清晨'], ['duet', 'B · 双声部'], ['unfold', 'C · 展开阅读']];
document.querySelectorAll('.preview-account-menu, .account-menu').forEach(menu => {
  const choices = document.createElement('div');
  choices.className = 'preview-theme-choices';
  const label = document.createElement('span');
  label.textContent = '阅读主题';
  choices.append(label);
  themes.forEach(([key, name]) => {
    const link = document.createElement('a');
    link.href = `${key}${scene === 'daily' ? '' : '-' + scene}.html${scene === 'library' ? '?view=' + libraryView : ''}`;
    link.textContent = name;
    if (key === theme) link.setAttribute('aria-current', 'true');
    link.addEventListener('click', event => {
      try { localStorage.setItem('lowpass-design-preview-theme-v2', key); } catch {}
      if (window.parent !== window) {
        event.preventDefault();
        window.parent.postMessage({ type: 'lowpass-preview-theme', theme: key, scene }, location.origin);
      }
    });
    choices.append(link);
  });
  menu.append(choices);
});

// Keep the existing preview shell on the destination opened inside its frame.
// Its own render updates src, so the replacement load does not send again.
if (window.frameElement?.id === 'frame' && new URL(window.frameElement.src).pathname !== location.pathname) {
  window.parent.postMessage({ type: 'lowpass-preview-theme', theme, scene }, location.origin);
}

requestAnimationFrame(() => requestAnimationFrame(() => document.body.classList.add('reader-ready')));
