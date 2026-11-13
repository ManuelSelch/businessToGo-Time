import React, { useState } from 'react';
import { createRoot } from 'react-dom/client';
import { Button, MantineProvider, createTheme } from '@mantine/core';
import { IconCalendar, IconChevronLeft, IconChevronRight, IconFilter, IconPlayerPlayFilled, IconChartBar, IconHome, IconClock, IconFolder } from '@tabler/icons-react';
import { Agentation } from 'agentation';
import '@mantine/core/styles.css';
import './styles.css';

const addDays = (date: Date, n: number) => { const d = new Date(date); d.setDate(d.getDate() + n); return d; };
const startWeek = (date: Date) => { const d = new Date(date.getFullYear(), date.getMonth(), date.getDate()); return addDays(d, -(d.getDay() + 6) % 7); };
const format = (date: Date, options: Intl.DateTimeFormatOptions) => new Intl.DateTimeFormat('de-DE', options).format(date);
const range = (date: Date) => `${format(date, {day:'numeric', month:'short'})} – ${format(addDays(date, 6), {day:'numeric', month:'short', year:'numeric'})}`;

function Calendar({week, select, close}: {week: Date; select: (d: Date) => void; close: () => void}) {
  const [month, setMonth] = useState(new Date(week.getFullYear(), week.getMonth(), 1));
  const first = startWeek(month);
  const days = Array.from({length: 42}, (_, i) => addDays(first, i));
  const changeMonth = (n: number) => setMonth(new Date(month.getFullYear(), month.getMonth() + n, 1));
  return <div className="backdrop" onClick={close}><section className="sheet" role="dialog" aria-modal="true" aria-label="Woche auswählen" onClick={e => e.stopPropagation()}>
    <div className="sheet-handle"/><div className="sheet-title"><span>Woche auswählen</span><button onClick={close}>Fertig</button></div>
    <div className="month"><button aria-label="Vorheriger Monat" onClick={() => changeMonth(-1)}><IconChevronLeft size={20}/></button><b>{format(month, {month:'long', year:'numeric'})}</b><button aria-label="Nächster Monat" onClick={() => changeMonth(1)}><IconChevronRight size={20}/></button></div>
    <div className="grid weekdays">{['Mo','Di','Mi','Do','Fr','Sa','So'].map(d => <span key={d}>{d}</span>)}</div>
    <div className="grid">{days.map(d => { const selected = startWeek(d).getTime() === week.getTime(); return <button key={d.toISOString()} className={`${selected ? 'selected' : ''} ${d.getMonth() !== month.getMonth() ? 'outside' : ''}`} onClick={() => {select(startWeek(d)); close();}}>{d.getDate()}</button>; })}</div>
    <Button variant="light" fullWidth onClick={() => { select(startWeek(new Date())); close(); }}>Diese Woche</Button>
  </section></div>;
}
function App() {
  const [week, setWeek] = useState(startWeek(new Date()));
  const [calendar, setCalendar] = useState(false);
  const [tab, setTab] = useState('Woche');
  const isCurrent = week.getTime() === startWeek(new Date()).getTime();
  const bars = isCurrent ? [40, 75, 57, 90, 48, 0, 0] : [65, 82, 45, 72, 56, 0, 0];
  return <main className="page"><div className="phone"><div className="status"><b>9:41</b><span>●●● ◒ ▰</span></div><header><h1>Berichte</h1><div className="toolbar"><button aria-label="Filter (nur Darstellung)"><IconFilter size={24}/></button><div className="segmented">{['Woche','Monat','Jahr'].map(t => <button key={t} className={tab === t ? 'active' : ''} onClick={() => setTab(t)}>{t}</button>)}</div><button aria-label="Start (nur Darstellung)"><IconPlayerPlayFilled size={21}/></button></div>
  {tab === 'Woche' ? <div className="week-nav"><button aria-label="Vorherige Woche" onClick={() => setWeek(addDays(week, -7))}><IconChevronLeft size={21}/></button><button className="date-button" onClick={() => setCalendar(true)}><IconCalendar size={18}/><span>{range(week)}</span></button><button aria-label="Nächste Woche" onClick={() => setWeek(addDays(week, 7))}><IconChevronRight size={21}/></button></div> : <div className="placeholder">{tab === 'Monat' ? 'Monatsbericht' : 'Jahresbericht'} · nur Darstellung</div>}</header>
  <div className="chart"><div className="chart-top"><span>Gesamt</span><strong>{isCurrent ? '32:15' : '36:30'} <small>Std.</small></strong></div><div className="bars">{bars.map((h,i) => <div className="barcol" key={i}><div className="bararea"><div className="bar" style={{height: `${h}%`}}/></div><span>{['Mo','Di','Mi','Do','Fr','Sa','So'][i]}</span></div>)}</div></div>
  <div className="list-title">ZEITEINTRÄGE <span>{range(week)}</span></div><div className="entries"><div className="entry"><div><b>Projektarbeit</b><p>BlueCat Bio · Entwicklung</p></div><strong>08:00</strong></div><div className="entry"><div><b>Team Meeting</b><p>Intern · Besprechung</p></div><strong>01:30</strong></div><div className="entry"><div><b>Konzeption</b><p>BlueCat Bio · Planung</p></div><strong>06:45</strong></div></div>
  <nav><div><IconHome/><span>Heute</span></div><div><IconClock/><span>Zeiten</span></div><div><IconFolder/><span>Projekte</span></div><div className="current"><IconChartBar/><span>Berichte</span></div></nav>{calendar && <Calendar week={week} select={setWeek} close={() => setCalendar(false)}/>}</div><p className="caption">Natives Erscheinungsbild · Interaktiver Entwurf</p></main>;
}
const theme = createTheme({primaryColor:'blue', fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif', defaultRadius:'md'});
createRoot(document.getElementById('root')!).render(<MantineProvider theme={theme}><App/>{import.meta.env.DEV && <Agentation />}</MantineProvider>);
