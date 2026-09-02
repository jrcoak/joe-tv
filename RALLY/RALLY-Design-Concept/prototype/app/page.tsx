'use client';

import { useEffect, useMemo, useState } from 'react';

type View = 'home' | 'guide' | 'sports' | 'player' | 'multiview' | 'case-study';
type Overlay = 'feed' | 'search' | 'profile' | 'program' | null;

const navItems: Array<{ label: string; view: View }> = [
  { label: 'Home', view: 'home' },
  { label: 'Live TV', view: 'guide' },
  { label: 'Sports', view: 'sports' },
];

const channelNames = [
  ['2', 'CBS', 'CBS 2', 'Local'], ['4', 'NBC', 'NBC 4', 'Local'], ['5', 'FOX', 'FOX 5', 'Local'],
  ['7', 'ESPN', 'ESPN', 'Sports'], ['8', 'ESPN2', 'ESPN2', 'Sports'], ['9', 'TNT', 'TNT', 'Entertainment'],
  ['10', 'TBS', 'TBS', 'Entertainment'], ['11', 'FS1', 'FOX Sports 1', 'Sports'], ['12', 'NFL', 'NFL Network', 'Sports'],
  ['13', 'MLB', 'MLB Network', 'Sports'], ['14', 'NBA', 'NBA TV', 'Sports'], ['15', 'NHL', 'NHL Network', 'Sports'],
  ['16', 'GOLF', 'Golf Channel', 'Sports'], ['17', 'BTN', 'Big Ten Network', 'Sports'], ['18', 'SEC', 'SEC Network', 'Sports'],
  ['19', 'ACC', 'ACC Network', 'Sports'], ['20', 'USA', 'USA Network', 'Entertainment'], ['21', 'FX', 'FX', 'Entertainment'],
  ['22', 'FXX', 'FXX', 'Entertainment'], ['23', 'AMC', 'AMC', 'Entertainment'], ['24', 'BRAVO', 'Bravo', 'Entertainment'],
  ['25', 'DISC', 'Discovery', 'Entertainment'], ['26', 'NATGEO', 'National Geographic', 'Entertainment'], ['27', 'HIST', 'History', 'Entertainment'],
  ['28', 'CNN', 'CNN', 'News'], ['29', 'MSNBC', 'MSNBC', 'News'], ['30', 'CNBC', 'CNBC', 'News'],
  ['31', 'NEWS', 'NewsNation', 'News'], ['32', 'BBC', 'BBC News', 'News'], ['33', 'LOCAL', 'Local Now', 'Local'],
  ['34', 'PBS', 'PBS', 'Local'], ['35', 'CW', 'The CW', 'Local'], ['36', 'ION', 'ION', 'Entertainment'],
  ['37', 'A&E', 'A&E', 'Entertainment'], ['38', 'HGTV', 'HGTV', 'Entertainment'], ['39', 'FOOD', 'Food Network', 'Entertainment'],
  ['40', 'TRVL', 'Travel Channel', 'Entertainment'], ['41', 'APL', 'Animal Planet', 'Entertainment'], ['42', 'MTV', 'MTV', 'Entertainment'],
  ['43', 'VH1', 'VH1', 'Entertainment'], ['44', 'COM', 'Comedy Central', 'Entertainment'], ['45', 'PAR', 'Paramount Network', 'Entertainment'],
  ['46', 'SYFY', 'SYFY', 'Entertainment'], ['47', 'FREE', 'Freeform', 'Entertainment'], ['48', 'HALL', 'Hallmark', 'Entertainment'],
  ['49', 'TCM', 'Turner Classic Movies', 'Entertainment'], ['50', 'WE', 'WE tv', 'Entertainment'], ['51', 'BET', 'BET', 'Entertainment'],
  ['52', 'CMT', 'CMT', 'Entertainment'], ['53', 'OWN', 'OWN', 'Entertainment'],
] as const;

const sportsPrograms = [
  ['Monday Night Countdown', 'Bills at Ravens', 'SportsCenter'],
  ['College Football Live', 'SEC Now', '30 for 30'],
  ['The Rally', 'Padres at Dodgers', 'MLB Tonight'],
  ['NBA Today', 'Seattle at Los Angeles', 'Inside the NBA'],
];

const generalPrograms = [
  ['Evening News', 'Prime Time', 'Late Report'],
  ['City Stories', 'The Long Way Home', 'Night Shift'],
  ['World Tonight', 'The Brief', 'Morning Edition'],
  ['Live from New York', 'After Hours', 'The Take'],
];

const channels = channelNames.map(([number, short, name, category], index) => {
  const source = short === 'ESPN'
    ? sportsPrograms[0]
    : category === 'Sports'
      ? sportsPrograms[index % sportsPrograms.length]
      : generalPrograms[index % generalPrograms.length];
  return {
    id: `channel-${number}`,
    number,
    short,
    name,
    category,
    favorite: ['2', '4', '7', '11', '12', '13', '14', '15'].includes(number),
    programs: [
      { id: `${number}-a`, title: source[0], time: '8:00–8:30 PM', live: false, width: 29 },
      { id: `${number}-b`, title: source[1], time: '8:30–9:30 PM', live: number === '7', width: 42 },
      { id: `${number}-c`, title: source[2], time: '9:30–10:00 PM', live: false, width: 29 },
    ],
  };
});

const gameCards = [
  { id: 'buf-bal', league: 'NFL', state: 'LIVE · 4TH · 08:12', away: 'Buffalo', home: 'Baltimore', awayCode: 'BUF', homeCode: 'BAL', awayScore: '24', homeScore: '21', note: '2nd & 6 · BAL 31', tone: 'blue' },
  { id: 'ny-bos', league: 'NBA', state: 'LIVE · 3RD · 04:22', away: 'New York', home: 'Boston', awayCode: 'NYK', homeCode: 'BOS', awayScore: '78', homeScore: '81', note: 'Tight game', tone: 'green' },
  { id: 'tor-mtl', league: 'NHL', state: 'LIVE · 2ND · 12:10', away: 'Toronto', home: 'Montréal', awayCode: 'TOR', homeCode: 'MTL', awayScore: '2', homeScore: '2', note: 'Power play · 1:24', tone: 'ice' },
  { id: 'sd-lad', league: 'MLB', state: '9:10 PM', away: 'San Diego', home: 'Los Angeles', awayCode: 'SD', homeCode: 'LAD', awayScore: '—', homeScore: '—', note: 'Home & away feeds', tone: 'gold' },
];

const focusable = (id: string, defaultFocus = false) => ({
  'data-focusable': 'true',
  'data-focus-id': id,
  'data-default-focus': defaultFocus ? 'true' : undefined,
});

export default function Home() {
  const [view, setView] = useState<View>('home');
  const [previous, setPrevious] = useState<{ view: View; focusId: string } | null>(null);
  const [overlay, setOverlay] = useState<Overlay>(null);
  const [guideFilter, setGuideFilter] = useState('All Channels');
  const [guideStart, setGuideStart] = useState(0);
  const [selectedProgram, setSelectedProgram] = useState({ channel: 'ESPN', title: 'Bills at Ravens', time: '8:30–9:30 PM', live: true });
  const [sportsTab, setSportsTab] = useState('Today');
  const [scoresHidden, setScoresHidden] = useState(false);
  const [paused, setPaused] = useState(false);
  const [toast, setToast] = useState('');
  const [audioPane, setAudioPane] = useState('buf-bal');

  const visibleGuide = useMemo(() => {
    let result = channels;
    if (guideFilter === 'Favorites') result = result.filter((channel) => channel.favorite);
    if (['Sports', 'News', 'Local'].includes(guideFilter)) result = result.filter((channel) => channel.category === guideFilter);
    return result;
  }, [guideFilter]);

  const pageChannels = visibleGuide.slice(guideStart, guideStart + 8);

  const currentFocusId = () => (document.activeElement as HTMLElement | null)?.dataset.focusId ?? '';

  const goTo = (nextView: View, returnFocus = '') => {
    setPrevious({ view, focusId: returnFocus || currentFocusId() });
    setOverlay(null);
    setView(nextView);
  };

  const goBack = () => {
    if (overlay) {
      setOverlay(null);
      return;
    }
    if (previous) {
      const destination = previous;
      setPrevious(null);
      setView(destination.view);
      window.setTimeout(() => document.querySelector<HTMLElement>(`[data-focus-id="${destination.focusId}"]`)?.focus(), 60);
      return;
    }
    if (view !== 'home') setView('home');
  };

  useEffect(() => {
    const timer = window.setTimeout(() => {
      if (overlay) {
        document.querySelector<HTMLElement>('.overlay-sheet [data-default-focus="true"]')?.focus();
        return;
      }
      const current = document.activeElement as HTMLElement | null;
      if (!current || current === document.body || !current.offsetParent) {
        document.querySelector<HTMLElement>('[data-default-focus="true"]')?.focus();
      }
    }, 80);
    return () => window.clearTimeout(timer);
  }, [view, overlay, sportsTab, guideStart, guideFilter]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement;
      const isTyping = ['INPUT', 'TEXTAREA'].includes(target.tagName);

      if (event.key === 'Escape') {
        event.preventDefault();
        goBack();
        return;
      }

      if (!isTyping && event.key.toLowerCase() === 'g' && view !== 'case-study') {
        event.preventDefault();
        goTo('guide');
        return;
      }

      if (!isTyping && event.code === 'Space' && view === 'player') {
        event.preventDefault();
        setPaused((value) => !value);
        return;
      }

      if (view === 'guide' && ['PageDown', 'PageUp'].includes(event.key)) {
        event.preventDefault();
        const direction = event.key === 'PageDown' ? 8 : -8;
        setGuideStart((value) => Math.max(0, Math.min(Math.max(0, visibleGuide.length - 8), value + direction)));
        return;
      }

      if (isTyping && event.key === 'ArrowDown') {
        event.preventDefault();
        document.querySelector<HTMLElement>('.quick-search [data-focusable="true"]')?.focus();
        return;
      }

      if (isTyping || !['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(event.key)) return;

      const focusScope = overlay ? document.querySelector('.overlay-sheet') : document;
      const nodes = Array.from(focusScope?.querySelectorAll<HTMLElement>('[data-focusable="true"]') ?? []).filter((node) => node.offsetParent !== null && !node.hasAttribute('disabled'));
      const active = document.activeElement as HTMLElement | null;
      if (!active || !nodes.includes(active)) {
        nodes[0]?.focus();
        return;
      }

      const from = active.getBoundingClientRect();
      const fx = from.left + from.width / 2;
      const fy = from.top + from.height / 2;
      const direction = event.key.replace('Arrow', '').toLowerCase();

      const ranked = nodes
        .filter((node) => node !== active)
        .map((node) => {
          const rect = node.getBoundingClientRect();
          const dx = rect.left + rect.width / 2 - fx;
          const dy = rect.top + rect.height / 2 - fy;
          const valid = direction === 'right' ? dx > 6 : direction === 'left' ? dx < -6 : direction === 'down' ? dy > 6 : dy < -6;
          const primary = ['left', 'right'].includes(direction) ? Math.abs(dx) : Math.abs(dy);
          const secondary = ['left', 'right'].includes(direction) ? Math.abs(dy) : Math.abs(dx);
          return { node, valid, score: primary + secondary * 2.8 };
        })
        .filter((candidate) => candidate.valid)
        .sort((a, b) => a.score - b.score);

      if (ranked[0]) {
        event.preventDefault();
        ranked[0].node.focus();
      }
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  });

  const pickProgram = (channel: typeof channels[number], program: typeof channels[number]['programs'][number]) => {
    setSelectedProgram({ channel: channel.name, title: program.title, time: program.time, live: program.live });
  };

  const selectProgram = (channel: typeof channels[number], program: typeof channels[number]['programs'][number]) => {
    pickProgram(channel, program);
    if (program.live) goTo('player', program.id);
    else setOverlay('program');
  };

  const changeFilter = (filter: string) => {
    setGuideFilter(filter);
    setGuideStart(0);
  };

  const notify = (message: string) => {
    setToast(message);
    window.setTimeout(() => setToast(''), 2500);
  };

  if (view === 'case-study') {
    return <CaseStudy onOpen={goTo} onBack={goBack} />;
  }

  return (
    <main className={`rally-app view-${view}`}>
      {view !== 'player' && view !== 'multiview' && (
        <TopRail
          view={view}
          onNavigate={goTo}
          onSearch={() => setOverlay('search')}
          onProfile={() => setOverlay('profile')}
          onCase={() => goTo('case-study')}
        />
      )}

      {view === 'home' && <HomeView onWatch={() => goTo('player', 'home-watch')} onSports={() => goTo('sports', 'home-sports')} onMultiview={() => goTo('multiview', 'home-multiview')} />}

      {view === 'guide' && (
        <GuideView
          channels={pageChannels}
          filter={guideFilter}
          total={visibleGuide.length}
          start={guideStart}
          selected={selectedProgram}
          onFilter={changeFilter}
          onFocusProgram={pickProgram}
          onSelectProgram={selectProgram}
          onPage={(delta) => setGuideStart((value) => Math.max(0, Math.min(Math.max(0, visibleGuide.length - 8), value + delta)))}
          onWatch={() => goTo('player', 'guide-watch')}
        />
      )}

      {view === 'sports' && (
        <SportsView
          activeTab={sportsTab}
          scoresHidden={scoresHidden}
          onTab={setSportsTab}
          onToggleScores={() => setScoresHidden((value) => !value)}
          onWatch={() => goTo('player', 'sports-watch')}
          onGame={(id) => id === 'sd-lad' ? setOverlay('program') : goTo('player', `game-${id}`)}
          onMultiview={() => goTo('multiview', 'sports-multiview')}
        />
      )}

      {view === 'player' && (
        <PlayerView
          paused={paused}
          onBack={goBack}
          onPause={() => setPaused((value) => !value)}
          onGuide={() => goTo('guide', 'player-guide')}
          onFeed={() => setOverlay('feed')}
          onMultiview={() => goTo('multiview', 'player-multiview')}
          onAction={notify}
        />
      )}

      {view === 'multiview' && (
        <Multiview
          audioPane={audioPane}
          onFocus={setAudioPane}
          onSelect={() => goTo('player', 'multiview-pane')}
          onBack={goBack}
        />
      )}

      {overlay && (
        <OverlaySheet
          type={overlay}
          selectedProgram={selectedProgram}
          scoresHidden={scoresHidden}
          onToggleScores={() => setScoresHidden((value) => !value)}
          onClose={() => setOverlay(null)}
          onWatch={() => { setOverlay(null); goTo('player', 'overlay-watch'); }}
          onNotify={notify}
        />
      )}

      {toast && <div className="toast" role="status" aria-live="polite">{toast}</div>}

      <RemoteHint view={view} />
    </main>
  );
}

function TopRail({ view, onNavigate, onSearch, onProfile, onCase }: {
  view: View;
  onNavigate: (view: View, focus?: string) => void;
  onSearch: () => void;
  onProfile: () => void;
  onCase: () => void;
}) {
  return (
    <header className="topbar">
      <button className="brand" onClick={() => onNavigate('home', 'brand')} type="button" {...focusable('brand')}>
        <span className="brand-mark">R</span><span>RALLY</span>
      </button>
      <nav className="primary-nav" aria-label="Primary navigation">
        {navItems.map((item) => (
          <button
            className={view === item.view ? 'nav-item is-active' : 'nav-item'}
            key={item.view}
            onClick={() => onNavigate(item.view, `nav-${item.view}`)}
            type="button"
            {...focusable(`nav-${item.view}`)}
          >{item.label}</button>
        ))}
      </nav>
      <div className="topbar-meta">
        <span className="clock">8:42 PM</span>
        <button className="utility-button review-button" onClick={onCase} type="button" aria-label="Open design case study" {...focusable('case-study')}>i</button>
        <button className="utility-button" onClick={onSearch} type="button" aria-label="Search" {...focusable('search')}><span className="search-icon" aria-hidden="true" /></button>
        <button className="avatar" onClick={onProfile} type="button" aria-label="Open Joe's profile" {...focusable('profile')}>JC</button>
      </div>
    </header>
  );
}

function HomeView({ onWatch, onSports, onMultiview }: { onWatch: () => void; onSports: () => void; onMultiview: () => void }) {
  return (
    <section className="home-screen" aria-labelledby="home-title">
      <div className="home-image" aria-hidden="true" />
      <div className="home-wash" aria-hidden="true" />
      <div className="home-hero">
        <div className="live-line"><span className="live-dot" /> NFL · LIVE · 4TH · 08:12</div>
        <p className="eyebrow">Sunday Night Football</p>
        <h1 id="home-title">Buffalo<br /><em>at</em> Baltimore</h1>
        <div className="hero-score" aria-label="Buffalo 24, Baltimore 21"><strong>24</strong><span>—</span><strong>21</strong></div>
        <p className="hero-copy">Buffalo has the ball at the Baltimore 31. One drive can change the night.</p>
        <div className="hero-actions">
          <button className="watch-button" onClick={onWatch} type="button" {...focusable('home-watch', true)}><span className="play-triangle" aria-hidden="true" /> Watch live</button>
          <button className="soft-button" onClick={() => {}} type="button" {...focusable('home-start')}>Start over</button>
          <button className="soft-button" onClick={onMultiview} type="button" {...focusable('home-multiview')}>Multiview <span>4</span></button>
        </div>
      </div>
      <div className="now-next" aria-label="Now and next">
        <div className="now-next-label"><span>Now & next</span><small>Personalized live lineup</small></div>
        <button className="mini-event is-current" onClick={onWatch} type="button" {...focusable('home-now-buf')}><span>LIVE · NFL</span><strong>BUF 24&nbsp;&nbsp; BAL 21</strong><small>4th · 08:12</small></button>
        <button className="mini-event" onClick={onSports} type="button" {...focusable('home-now-nba')}><span>LIVE · NBA</span><strong>NYK 78&nbsp;&nbsp; BOS 81</strong><small>3rd · 04:22</small></button>
        <button className="mini-event" onClick={onSports} type="button" {...focusable('home-now-mlb')}><span>9:10 · MLB</span><strong>SD at LAD</strong><small>Home & away feeds</small></button>
        <button className="mini-event build-mix" onClick={onMultiview} type="button" {...focusable('home-now-mix')}><span>TONIGHT'S PLAN</span><strong>Build multiview</strong><small>3 games overlap</small></button>
      </div>
    </section>
  );
}

function GuideView({ channels, filter, total, start, selected, onFilter, onFocusProgram, onSelectProgram, onPage, onWatch }: {
  channels: typeof channels;
  filter: string;
  total: number;
  start: number;
  selected: { channel: string; title: string; time: string; live: boolean };
  onFilter: (filter: string) => void;
  onFocusProgram: (channel: typeof channels[number], program: typeof channels[number]['programs'][number]) => void;
  onSelectProgram: (channel: typeof channels[number], program: typeof channels[number]['programs'][number]) => void;
  onPage: (delta: number) => void;
  onWatch: () => void;
}) {
  return (
    <section className="guide-screen" aria-labelledby="guide-heading">
      <div className="guide-intro">
        <div>
          <div className="guide-kicker"><span>{selected.live ? 'LIVE NOW' : selected.time}</span><span>{selected.channel}</span></div>
          <h1 id="guide-heading">{selected.title}</h1>
          <p>{selected.live ? 'Buffalo has the ball at the Baltimore 31 · 4th · 08:12' : `${selected.time} · Program details and availability`}</p>
          <div className="guide-actions">
            <button className="compact-action" onClick={onWatch} type="button" {...focusable('guide-watch', true)}>{selected.live ? 'Watch live' : 'View details'}</button>
            <button className="text-action" type="button" {...focusable('guide-favorite')}>＋ Favorite channel</button>
          </div>
        </div>
        <button className="guide-preview" onClick={onWatch} type="button" aria-label="Return to live preview" {...focusable('guide-preview')}>
          <span className="preview-art" />
          <span className="preview-label"><i className="live-dot" /> LIVE · ESPN</span>
        </button>
      </div>

      <div className="guide-toolbar">
        <div className="guide-filters" aria-label="Channel groups">
          {['Favorites', 'Sports', 'News', 'Local', 'All Channels'].map((item) => (
            <button className={filter === item ? 'filter-button is-active' : 'filter-button'} key={item} onClick={() => onFilter(item)} type="button" {...focusable(`filter-${item}`)}>{item}</button>
          ))}
        </div>
        <div className="guide-page"><button onClick={() => onPage(-8)} type="button" aria-label="Previous eight channels" {...focusable('guide-page-up')}>↑</button><span>{Math.min(start + 1, total)}–{Math.min(start + channels.length, total)} of {total}</span><button onClick={() => onPage(8)} type="button" aria-label="Next eight channels" {...focusable('guide-page-down')}>↓</button></div>
      </div>

      <div className="epg" role="grid" aria-label={`${filter} program guide`}>
        <div className="epg-corner"><span>Channels</span></div>
        <div className="time-ruler"><span>8:00</span><span>8:30</span><span>9:00</span><span>9:30</span><span>10:00</span><i className="now-label">NOW 8:42</i></div>
        {channels.map((channel, rowIndex) => (
          <div className="epg-row" role="row" key={channel.id}>
            <button className="channel-cell" type="button" aria-label={`${channel.number} ${channel.name}`} {...focusable(`channel-${channel.number}`)}>
              <span className="channel-number">{channel.number}</span><strong>{channel.short}</strong><small>{channel.name}</small>{channel.favorite && <i>★</i>}
            </button>
            <div className="program-track">
              {channel.programs.map((program, programIndex) => (
                <button
                  className={program.live ? 'program-cell is-live' : 'program-cell'}
                  key={program.id}
                  onClick={() => onSelectProgram(channel, program)}
                  onFocus={() => onFocusProgram(channel, program)}
                  style={{ width: `${program.width}%` }}
                  type="button"
                  role="gridcell"
                  {...focusable(program.id, rowIndex === 3 && programIndex === 1)}
                >
                  <strong>{program.title}</strong><span>{program.live ? 'LIVE · 32 min left' : program.time.split('–')[0]}</span>
                </button>
              ))}
              <i className="now-line" aria-hidden="true" />
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

function SportsView({ activeTab, scoresHidden, onTab, onToggleScores, onWatch, onGame, onMultiview }: {
  activeTab: string;
  scoresHidden: boolean;
  onTab: (tab: string) => void;
  onToggleScores: () => void;
  onWatch: () => void;
  onGame: (id: string) => void;
  onMultiview: () => void;
}) {
  return (
    <section className="sports-screen" aria-labelledby="sports-heading">
      <div className="sports-heading-row">
        <div><p className="eyebrow">Wednesday · August 26</p><h1 id="sports-heading">Tonight is loaded.</h1></div>
        <button className={scoresHidden ? 'shield-button is-active' : 'shield-button'} onClick={onToggleScores} type="button" {...focusable('score-shield')}><span className="shield-icon">◇</span>{scoresHidden ? 'Scores hidden' : 'Spoiler shield'}</button>
      </div>
      <nav className="sports-tabs" aria-label="Sports views">
        {['Today', 'Schedule', 'Leagues', 'My Teams', 'Replays'].map((tab) => <button className={activeTab === tab ? 'sports-tab is-active' : 'sports-tab'} key={tab} onClick={() => onTab(tab)} type="button" {...focusable(`sports-${tab}`, tab === 'Today')}>{tab}</button>)}
      </nav>

      {activeTab === 'Today' ? (
        <div className="sports-today">
          <article className="sports-feature">
            <div className="feature-art" aria-hidden="true" />
            <div className="feature-wash" />
            <div className="feature-content">
              <div className="live-line"><span className="live-dot" /> Live · 4th · 08:12</div>
              <p className="eyebrow">Your game · NFL</p>
              <h2>Buffalo at<br />Baltimore</h2>
              <div className="feature-score"><span>BUF</span><strong>{scoresHidden ? '—' : '24'}</strong><i>—</i><span>BAL</span><strong>{scoresHidden ? '—' : '21'}</strong></div>
              <p>{scoresHidden ? 'Game in progress' : '2nd & 6 · Baltimore 31'}</p>
              <div className="feature-actions"><button onClick={onWatch} type="button" {...focusable('sports-watch', true)}>Watch live</button><button onClick={() => {}} type="button" {...focusable('sports-catchup')}>Catch up · 1:48</button></div>
            </div>
          </article>

          <div className="live-spine">
            <div className="section-title"><div><span className="live-dot" /> Live now</div><small>3 games</small></div>
            {gameCards.slice(1, 3).map((game) => <GameCard key={game.id} game={game} scoresHidden={scoresHidden} onClick={() => onGame(game.id)} />)}
            <button className="tonights-plan" onClick={onMultiview} type="button" {...focusable('sports-plan')}><span>TONIGHT'S PLAN</span><strong>Three favorites overlap.</strong><small>We built a four-screen mix for you.</small><b>Open multiview →</b></button>
          </div>

          <div className="later-row">
            <div className="section-title"><div>Later today</div><small>Local time</small></div>
            <GameCard game={gameCards[3]} scoresHidden={scoresHidden} onClick={() => onGame('sd-lad')} compact />
            <button className="later-simple" onClick={() => onGame('sea-la')} type="button" {...focusable('later-wnba')}><span>10:00 PM · WNBA</span><strong>Seattle at Los Angeles</strong><small>ESPN · Record scheduled</small></button>
            <button className="later-simple" onClick={() => onGame('nyr-nj')} type="button" {...focusable('later-nhl')}><span>10:30 PM · NHL</span><strong>New York at New Jersey</strong><small>Home & away feeds</small></button>
          </div>
        </div>
      ) : (
        <SportsSubView tab={activeTab} onGame={onGame} />
      )}
    </section>
  );
}

function GameCard({ game, scoresHidden, onClick, compact = false }: { game: typeof gameCards[number]; scoresHidden: boolean; onClick: () => void; compact?: boolean }) {
  return (
    <button className={`game-card tone-${game.tone}${compact ? ' is-compact' : ''}`} onClick={onClick} onFocus={() => {}} type="button" {...focusable(`game-${game.id}`)}>
      <span className="game-state">{game.state}</span>
      <div className="game-team"><span>{game.awayCode}</span><strong>{game.away}</strong><b>{scoresHidden ? '—' : game.awayScore}</b></div>
      <div className="game-team"><span>{game.homeCode}</span><strong>{game.home}</strong><b>{scoresHidden ? '—' : game.homeScore}</b></div>
      <small>{scoresHidden ? 'Game in progress' : game.note}</small>
    </button>
  );
}

function SportsSubView({ tab, onGame }: { tab: string; onGame: (id: string) => void }) {
  const copy: Record<string, [string, string]> = {
    Schedule: ['The whole day, in order.', 'A stable chronological view grouped by start time.'],
    Leagues: ['One system. Four worlds.', 'NFL, MLB, NBA, and NHL share one interaction grammar.'],
    'My Teams': ['Your teams move first.', 'Favorites, recordings, and the next games that matter.'],
    Replays: ['Choose your time commitment.', 'Two minutes, condensed, or the whole game.'],
  };
  const [title, subtitle] = copy[tab] ?? copy.Schedule;
  return (
    <div className="sports-subview">
      <div className="subview-copy"><span>{tab}</span><h2>{title}</h2><p>{subtitle}</p></div>
      <div className="subview-grid">
        {gameCards.map((game) => <GameCard key={game.id} game={game} scoresHidden={false} onClick={() => onGame(game.id)} />)}
      </div>
    </div>
  );
}

function PlayerView({ paused, onBack, onPause, onGuide, onFeed, onMultiview, onAction }: {
  paused: boolean;
  onBack: () => void;
  onPause: () => void;
  onGuide: () => void;
  onFeed: () => void;
  onMultiview: () => void;
  onAction: (message: string) => void;
}) {
  return (
    <section className="player-screen" aria-label="Live player">
      <div className="player-image" aria-hidden="true" />
      <div className="player-shade" />
      <button className="player-back" onClick={onBack} type="button" aria-label="Back" {...focusable('player-back')}>←</button>
      <div className="scorebug"><span className="live-dot" /><small>NFL · 4TH · 08:12</small><strong>BUF&nbsp; 24</strong><i>—</i><strong>BAL&nbsp; 21</strong><b>2nd & 6</b></div>
      {paused && <div className="pause-state"><span>Ⅱ</span><small>Paused at 8:12</small></div>}
      <div className="player-controls">
        <div className="player-title"><div><span>ESPN · Buffalo at Baltimore</span><h1>Sunday Night Football</h1></div><p>Live edge</p></div>
        <div className="timeline"><span style={{ width: '78%' }} /><i>LIVE</i></div>
        <div className="control-row">
          <button onClick={onPause} type="button" {...focusable('control-pause', true)}><b>{paused ? '▶' : 'Ⅱ'}</b><span>{paused ? 'Play' : 'Pause'}</span></button>
          <button onClick={() => onAction('Playing from the beginning')} type="button" {...focusable('control-start')}><b>↶</b><span>Start over</span></button>
          <button onClick={() => onAction('Captions on')} type="button" {...focusable('control-captions')}><b>CC</b><span>Captions</span></button>
          <button onClick={onFeed} type="button" {...focusable('control-feed')}><b>◉</b><span>Feed</span></button>
          <button onClick={onMultiview} type="button" {...focusable('control-multiview')}><b>▦</b><span>Multiview</span></button>
          <button onClick={() => onAction('Bills added to My Teams')} type="button" {...focusable('control-favorite')}><b>＋</b><span>Favorite</span></button>
          <button onClick={onGuide} type="button" {...focusable('control-guide')}><b>▤</b><span>Guide</span></button>
        </div>
      </div>
    </section>
  );
}

function Multiview({ audioPane, onFocus, onSelect, onBack }: { audioPane: string; onFocus: (id: string) => void; onSelect: () => void; onBack: () => void }) {
  const panes = [
    { id: 'buf-bal', label: 'BUF 24 · BAL 21', meta: 'NFL · 4th · 08:12', cls: 'football' },
    { id: 'ny-bos', label: 'NYK 78 · BOS 81', meta: 'NBA · 3rd · 04:22', cls: 'basketball' },
    { id: 'tor-mtl', label: 'TOR 2 · MTL 2', meta: 'NHL · 2nd · 12:10', cls: 'hockey' },
    { id: 'sd-lad', label: 'SD at LAD', meta: 'MLB · Starts 9:10', cls: 'baseball' },
  ];
  return (
    <section className="multiview-screen" aria-labelledby="multiview-title">
      <div className="multiview-top"><button onClick={onBack} type="button" {...focusable('multiview-back')}>← Back</button><div><p className="eyebrow">Tonight's plan</p><h1 id="multiview-title">Multiview</h1></div><span>Move focus to change audio</span></div>
      <div className="pane-grid">
        {panes.map((pane, index) => (
          <button className={`view-pane ${pane.cls}${audioPane === pane.id ? ' has-audio' : ''}`} key={pane.id} onClick={onSelect} onFocus={() => onFocus(pane.id)} type="button" {...focusable(`pane-${pane.id}`, index === 0)}>
            <span className="pane-art" /><span className="pane-shade" /><span className="pane-copy"><small>{pane.meta}</small><strong>{pane.label}</strong></span>{audioPane === pane.id && <i>◖ AUDIO</i>}
          </button>
        ))}
      </div>
      <div className="multiview-actions"><button type="button" {...focusable('multiview-replace')}>Replace game</button><button type="button" {...focusable('multiview-layout')}>Layout</button><button type="button" {...focusable('multiview-feed')}>Broadcasts</button></div>
    </section>
  );
}

function OverlaySheet({ type, selectedProgram, scoresHidden, onToggleScores, onClose, onWatch, onNotify }: {
  type: Exclude<Overlay, null>;
  selectedProgram: { channel: string; title: string; time: string; live: boolean };
  scoresHidden: boolean;
  onToggleScores: () => void;
  onClose: () => void;
  onWatch: () => void;
  onNotify: (message: string) => void;
}) {
  return (
    <div className="overlay-layer" role="presentation">
      <button className="overlay-dismiss" aria-label="Close" onClick={onClose} type="button" />
      <section className={`overlay-sheet overlay-${type}`} role="dialog" aria-modal="true" aria-label={`${type} options`}>
        <button className="sheet-close" aria-label="Close options" onClick={onClose} type="button" {...focusable('overlay-close')}>×</button>
        <div className="sheet-handle" />
        {type === 'feed' && <>
          <p className="eyebrow">Broadcast</p><h2>Choose the voices you know.</h2><p className="sheet-subtitle">Playback stays exactly where it is.</p>
          <div className="feed-list">
            {[['Recommended', 'National broadcast', 'ESPN · English · 1080p'], ['Television', 'Buffalo home broadcast', 'WKBW · English · 1080p'], ['Television', 'Baltimore home broadcast', 'WBAL · English · 1080p'], ['Languages', 'Spanish broadcast', 'ESPN Deportes · 1080p'], ['Radio', 'Buffalo radio', 'WGR 550 · Audio only']].map((feed, index) => (
              <button key={feed[1]} onClick={() => { onClose(); onNotify(`Using ${feed[1].toLowerCase()}`); }} type="button" {...focusable(`feed-${index}`, index === 0)}><span>{feed[0]}</span><strong>{feed[1]}</strong><small>{feed[2]}</small>{index === 0 && <b>✓</b>}</button>
            ))}
          </div>
        </>}
        {type === 'search' && <>
          <p className="eyebrow">Search</p><h2>What do you want to watch?</h2>
          <input autoFocus aria-label="Search games, teams, channels, and shows" placeholder="Games, teams, channels, shows" />
          <div className="quick-search"><span>Popular now</span>{['Bills at Ravens', 'ESPN', 'Yankees', 'NBA', 'SportsCenter'].map((item, index) => <button key={item} onClick={index === 0 ? onWatch : () => {}} type="button" {...focusable(`search-${index}`)}>{item}<i>→</i></button>)}</div>
        </>}
        {type === 'profile' && <>
          <p className="eyebrow">Joe's profile</p><h2>Your living room, your rules.</h2>
          <div className="setting-list">
            <button onClick={onToggleScores} type="button" {...focusable('profile-scores', true)}><span>◇</span><strong>Spoiler shield</strong><small>{scoresHidden ? 'Strict · scores and result-aware art hidden' : 'Off · scores are visible'}</small><b>{scoresHidden ? 'ON' : 'OFF'}</b></button>
            <button type="button" {...focusable('profile-captions')}><span>CC</span><strong>Captions</strong><small>Match system style</small><b>›</b></button>
            <button type="button" {...focusable('profile-audio')}><span>◉</span><strong>Preferred broadcasts</strong><small>Home feeds for Buffalo and New York</small><b>›</b></button>
          </div>
        </>}
        {type === 'program' && <>
          <p className="eyebrow">{selectedProgram.channel} · {selectedProgram.time}</p><h2>{selectedProgram.title}</h2><p className="sheet-subtitle">A single canonical program connects the channel, game, feeds, recording, and replay.</p>
          <div className="large-choices"><button onClick={() => onNotify('Reminder set for 9:10 PM')} type="button" {...focusable('program-remind', true)}><span>01</span><strong>Remind me</strong><small>Five minutes before</small></button><button type="button" {...focusable('program-record')}><span>02</span><strong>Record</strong><small>Keep until watched</small></button><button type="button" {...focusable('program-details')}><span>03</span><strong>Game details</strong><small>Feeds, venue, probable starters</small></button></div>
        </>}
      </section>
    </div>
  );
}

function RemoteHint({ view }: { view: View }) {
  return <footer className="remote-hint"><span><i className="remote-key">← ↑ ↓ →</i> Move</span><span><i className="remote-key">OK</i> Select</span><span><i className="remote-key">G</i> Guide</span>{view === 'player' && <span><i className="remote-key">SPACE</i> Play / pause</span>}<span><i className="remote-key">ESC</i> Back</span></footer>;
}

function CaseStudy({ onOpen, onBack }: { onOpen: (view: View) => void; onBack: () => void }) {
  return (
    <main className="case-study">
      <nav className="case-nav"><button onClick={onBack} type="button" {...focusable('case-back', true)}>← Back to RALLY</button><span>Product design concept · 2026</span></nav>
      <header className="case-hero"><p className="eyebrow">RALLY / Live TV, alive.</p><h1>Fifty channels.<br />Every game.<br /><em>One calm system.</em></h1><p>A remote-first streaming concept designed to make live television feel immediate, sports feel coherent, and every return to the couch feel personal.</p><button onClick={() => onOpen('home')} type="button" {...focusable('case-open')}>Explore the prototype →</button></header>

      <section className="case-principles"><p className="case-section-label">01 · North star</p><h2>The game stays on screen.<br />The interface moves around it.</h2><div className="principle-grid"><article><span>Browse</span><h3>Cinematic</h3><p>One dominant live story, purposeful art, no catalog wall.</p></article><article><span>Watch</span><h3>Invisible</h3><p>Playback is the hero. Controls appear only on intent.</p></article><article><span>Scan</span><h3>Exact</h3><p>The guide behaves like a timeline instrument, not a spreadsheet.</p></article></div></section>

      <section className="case-system"><p className="case-section-label">02 · Interaction grammar</p><div className="case-copy"><h2>Designed around four directions and a back button.</h2><p>Every screen has one unmistakable focus target. Focus never tunes a channel, scores never reorder the row beneath you, and Back reverses exactly one layer before restoring your last position.</p></div><div className="focus-demo"><div className="focus-card"><small>LIVE · NFL</small><strong>Buffalo at Baltimore</strong><span>Focus</span></div><ul><li><b>160ms</b> focus motion</li><li><b>4px</b> universal signal</li><li><b>96 × 60px</b> safe area</li><li><b>64px</b> minimum target</li></ul></div></section>

      <section className="case-screens"><p className="case-section-label">03 · Signature surfaces</p><h2>One event. Every valid way in.</h2><div className="screen-grid"><button onClick={() => onOpen('home')} type="button" {...focusable('case-home')}><span className="screen-thumb thumb-home" /><small>01</small><strong>Live home</strong><p>A live favorite becomes the hero.</p></button><button onClick={() => onOpen('guide')} type="button" {...focusable('case-guide')}><span className="screen-thumb thumb-guide" /><small>02</small><strong>50-channel guide</strong><p>Time, channel, and now stay aligned.</p></button><button onClick={() => onOpen('sports')} type="button" {...focusable('case-sports')}><span className="screen-thumb thumb-sports" /><small>03</small><strong>Sports today</strong><p>A game-first view across every league.</p></button><button onClick={() => onOpen('multiview')} type="button" {...focusable('case-multi')}><span className="screen-thumb thumb-multi" /><small>04</small><strong>Multiview</strong><p>Focus changes audio; Select goes full screen.</p></button></div></section>

      <section className="case-architecture"><p className="case-section-label">04 · Product architecture</p><h2>Channels and games are peers, not duplicates.</h2><div className="architecture-map"><article><span>CHANNEL</span><strong>ESPN</strong><p>Schedule · program · live stream</p></article><i>＋</i><article><span>EVENT</span><strong>Bills at Ravens</strong><p>Score · state · rights · replay</p></article><i>→</i><article className="canonical"><span>ONE DESTINATION</span><strong>Watch live</strong><p>Best included feed, silently resolved</p></article></div></section>

      <section className="case-details"><p className="case-section-label">05 · Delight in the details</p><div className="detail-grid"><article><span>01</span><h3>Moment-aware return</h3><p>“Catch up since you left · 0:52” gets you current without spoiling the turn.</p></article><article><span>02</span><h3>Spoiler Shield</h3><p>Scores, headlines, artwork, progress, and replay length all become neutral.</p></article><article><span>03</span><h3>Rights, resolved</h3><p>A blocked league feed becomes “Watch live on ESPN,” not a dead end.</p></article><article><span>04</span><h3>Broadcast memory</h3><p>Home commentary and language preferences follow the team, not the device.</p></article></div></section>

      <section className="case-foundation"><p className="case-section-label">06 · Foundation</p><div><h2>Warm black.<br />Signal coral.<br />Focus only in volt.</h2><p>League color changes atmosphere, never navigation. Translucency is reserved for temporary layers over video. Dense information stays opaque and exact.</p></div><div className="swatches"><span style={{ background: '#080a0d' }}><i>#080A0D</i></span><span style={{ background: '#f4f2ed', color: '#080a0d' }}><i>#F4F2ED</i></span><span style={{ background: '#ff5b35' }}><i>#FF5B35</i></span><span style={{ background: '#d6ff4b', color: '#080a0d' }}><i>#D6FF4B</i></span></div></section>

      <section className="case-research"><p className="case-section-label">07 · Evidence, not imitation</p><h2>Built from platform behavior and the best live-sports patterns.</h2><div><a href="https://developer.apple.com/design/human-interface-guidelines/live-viewing-apps" target="_blank" rel="noreferrer">Apple · Live-viewing apps ↗</a><a href="https://developer.android.com/design/ui/tv/guides/styles/focus-system" target="_blank" rel="noreferrer">Android TV · Focus system ↗</a><a href="https://support.google.com/youtubetv/answer/15456617?hl=en" target="_blank" rel="noreferrer">YouTube TV · Sunday Ticket ↗</a><a href="https://www.mlb.com/news/mlb-tv-features-faq-2025" target="_blank" rel="noreferrer">MLB.TV · Features ↗</a><a href="https://support.watch.nba.com/hc/en-us/articles/26849702436247-Multiview" target="_blank" rel="noreferrer">NBA · Multiview ↗</a><a href="https://www.work.co/clients/pga-tour/" target="_blank" rel="noreferrer">Work & Co · PGA TOUR ↗</a></div></section>

      <footer className="case-footer"><span>RALLY</span><h2>Meet the whole night.</h2><button onClick={() => onOpen('home')} type="button" {...focusable('case-final')}>Enter the living room →</button></footer>
    </main>
  );
}
