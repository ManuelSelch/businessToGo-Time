import React, { useState } from 'react';
import { createRoot } from 'react-dom/client';
import { Button, MantineProvider, createTheme } from '@mantine/core';
import { IconCalendar, IconChartBar, IconChevronLeft, IconChevronRight, IconClock, IconFolder, IconHome } from '@tabler/icons-react';
import { Agentation } from 'agentation';
import '@mantine/core/styles.css';
import './styles.css';

type Entry = { title: string; customer: string; start: number; end: number; color: string };
const examples: Record<string, Entry[]> = {
  'Arbeitstag': [{title:'Konzeption & Planung',customer:'Nord Studio',start:510,end:615,color:'blue'},{title:'Team-Meeting',customer:'Nord Studio',start:630,end:720,color:'violet'},{title:'Implementierung',customer:'Atelier West',start:780,end:930,color:'teal'}],
  'Kurzer Termin': [{title:'Kurzer Anruf',customer:'Nord Studio',start:855,end:860,color:'blue'}],
  'Spät am Abend': [{title:'Bereitschaft',customer:'Atelier West',start:1365,end:1440,color:'teal'}],
};
const time = (minute:number) => `${String(Math.floor(minute / 60)).padStart(2,'0')}:${String(minute % 60).padStart(2,'0')}`;
function Timeline({entries}:{entries:Entry[]}) {
  const start = Math.floor(Math.min(...entries.map(e=>e.start))/60)*60;
  const end = Math.min(1440, Math.max(start+60, Math.ceil(Math.max(...entries.map(e=>e.end))/60)*60));
  let bottom = 0;
  const positions = entries.map(e => {const top=Math.max((e.start-start)*2,bottom); const height=Math.max(40,(e.end-e.start)*2); bottom=top+height; return {...e,top,height};});
  const height = Math.max((end-start)*2,bottom);
  return <section className="timeline"><div className="timeline-grid" style={{height}}>{Array.from({length:(end-start)/60+1},(_,i)=><div className="hour" style={{top:i*120}} key={i}><span>{time(start+i*60)}</span><i/></div>)}<div className="event-column">{positions.map(e=><button key={e.title} className={'event '+e.color} style={{top:e.top,height:e.height}}><strong>{e.title}</strong><span className="event-time">{time(e.start)} – {time(e.end)}</span><small>{e.customer}</small></button>)}</div></div></section>;
}
function App(){const [example,setExample]=useState('Arbeitstag'); return <main className="canvas"><div className="review-head"><div><span>BERICHTE / TAGESANSICHT</span><h1>Eine kompaktere Timeline.</h1><p>Wähle ein Beispiel: Die Zeitachse beginnt und endet an den nächsten vollen Stunden um die Einträge.</p></div></div><div className="sample-controls">{Object.keys(examples).map(name=><Button key={name} size="xs" variant={example===name?'filled':'light'} onClick={()=>setExample(name)}>{name}</Button>)}</div><div className="phone"><div className="status"><b>9:41</b><span>●●● ◒ ▰</span></div><header><div className="titlebar"><h1>Berichte</h1></div><div className="segments"><button className="active">Tag</button><button>Woche</button><button>Monat</button><button>Jahr</button></div><div className="date-nav"><IconChevronLeft size={20}/><b><IconCalendar size={15}/> Mittwoch, 18. Juni 2025</b><IconChevronRight size={20}/></div></header><div className="content"><section className="summary"><div className="summary-top"><div><span>ZEIT</span><div className="total">{example==='Kurzer Termin'?'0:05':example==='Spät am Abend'?'1:15':'5:45'} <small>Std.</small></div></div><div className="revenue"><span>EINNAHMEN</span><b>–</b></div></div></section><Timeline entries={examples[example]}/></div><nav><div><IconHome/><span>Heute</span></div><div><IconClock/><span>Zeiten</span></div><div><IconFolder/><span>Projekte</span></div><div className="current"><IconChartBar/><span>Berichte</span></div></nav></div><p className="footnote">Beispieldaten · Einträge und andere Ansichten sind nicht interaktiv</p></main>}
createRoot(document.getElementById('root')!).render(<MantineProvider theme={createTheme({primaryColor:'blue',fontFamily:'-apple-system, BlinkMacSystemFont, sans-serif'})}><App/>{import.meta.env.DEV && <Agentation/>}</MantineProvider>);
