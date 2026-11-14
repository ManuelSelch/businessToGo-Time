import React, { useState } from 'react';
import { createRoot } from 'react-dom/client';
import { MantineProvider, Switch, createTheme } from '@mantine/core';
import { IconChevronLeft, IconChevronRight, IconSettings } from '@tabler/icons-react';
import { Agentation } from 'agentation';
import '@mantine/core/styles.css';
import './styles.css';

type Page = 'Today' | 'Settings' | 'Debug' | 'Integrations' | 'Intro' | 'Local Logs';
function App() {
  const [page, setPage] = useState<Page>('Today');
  const [remote, setRemote] = useState(false);
  const [mocks, setMocks] = useState(false);
  const back = () => setPage(page === 'Settings' ? 'Today' : page === 'Local Logs' ? 'Debug' : 'Settings');
  return <main className="stage"><div className="phone">
    <div className="status"><span>9:41</span><span>● ● ▰</span></div>
    <header><button className="gear" aria-label="Settings" onClick={() => setPage('Settings')}><IconSettings size={22}/></button></header>
    <div className="content"><h1>Today</h1><p className="hint">Your time at a glance</p><div className="card placeholder">No time entries yet</div></div>
    <footer><span>◉<small>Today</small></span><span>▤<small>Manage</small></span><span>▥<small>Reports</small></span></footer>
    {page !== 'Today' && <><div className="scrim" onClick={() => setPage('Today')}/><section className="sheet"><div className="handle"/><div className="sheet-header">{page !== 'Settings' && <button className="back" onClick={back}><IconChevronLeft size={20}/>{page === 'Local Logs' ? 'Debug' : ''}</button>}</div><div className="sheet-content"><h1>{page}</h1>
    {page === 'Settings' && <div className="card">{(['Integrations','Debug','Intro'] as const).map(item => <button className="row link" key={item} onClick={() => setPage(item)}>{item}<IconChevronRight size={17}/></button>)}<button className="row danger" onClick={() => {}}>Logout</button></div>}
    {page === 'Debug' && <><div className="section-label">GENERAL</div><div className="card"><button className="row danger" onClick={() => {}}>Reset Database</button><div className="row">Remote Log<Switch checked={remote} onChange={e => setRemote(e.currentTarget.checked)} aria-label="Remote Log" color="teal" /></div><button className="row link" onClick={() => setPage('Local Logs')}>Local Logs<IconChevronRight size={17}/></button><div className="row">Mocks<Switch checked={mocks} onChange={e => setMocks(e.currentTarget.checked)} aria-label="Mocks" color="teal"/></div></div><div className="section-label">ACCOUNT</div><div className="card account"><strong>Example account</strong><span>Kimai: example</span><span>Taiga: example</span></div></>}
    {['Integrations','Intro','Local Logs'].includes(page) && <p className="hint">Existing screen (not redesigned in this mockup).</p>}
    </div></section></>}
  </div></main>;
}
createRoot(document.getElementById('root')!).render(<MantineProvider theme={createTheme({fontFamily:'-apple-system, BlinkMacSystemFont, sans-serif',primaryColor:'teal'})}><App/>{import.meta.env.DEV && <Agentation/>}</MantineProvider>);
