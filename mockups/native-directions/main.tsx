import React, { useState } from 'react';
import { createRoot } from 'react-dom/client';
import { ActionIcon, Badge, Button, MantineProvider, Menu, Modal, MultiSelect, SegmentedControl, Select, Switch, TextInput, createTheme } from '@mantine/core';
import { IconArrowLeft, IconArrowRight, IconBatteryFilled, IconChartBar, IconCheck, IconChevronDown, IconChevronRight, IconClock, IconCloudOff, IconFolder, IconPlayerPlayFilled, IconPlus, IconRefresh, IconSettings, IconSquareFilled, IconWifi, IconX } from '@tabler/icons-react';
import { Agentation } from 'agentation';
import '@mantine/core/styles.css';
import './styles.css';

type Screen = 'Heute' | 'Projekte' | 'Berichte';
type ReviewState = 'running' | 'idle' | 'empty' | 'offline';
const teams = ['Entwicklung','Design','Operations'];
const projects = [
  {name:'Mobile App',customer:'Nord Studio',activity:'Entwicklung',color:'blue',time:'2 Std. 24 Min.',teams:['Entwicklung','Design']},
  {name:'Website Relaunch',customer:'Atelier West',activity:'Konzeption',color:'orange',time:'1 Std. 30 Min.',teams:['Design']},
  {name:'Organisation',customer:'Intern',activity:'Administration',color:'purple',time:'45 Min.',teams:['Operations']}
];
const theme = createTheme({ primaryColor:'brand',colors:{brand:['#edf9f3','#d5f2e4','#b4eacf','#84E2B1','#5bc69b','#30967b','#073E43','#06373c','#052f34','#04282c']},primaryShade:{light:6,dark:3},fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',defaultRadius:'md',components:{Button:{defaultProps:{size:'md'}},ActionIcon:{defaultProps:{size:44,variant:'subtle'}}} });

type CustomerDraft = {name:string;teams:string[]};
function NewCustomerForm({initialTeam,onSave}:{initialTeam:string|null;onSave:(customer:CustomerDraft)=>void}) {
 const [name,setName]=useState('');
 const [selectedTeams,setSelectedTeams]=useState<string[]>(initialTeam?[initialTeam]:[]);
 return <form className="sheet-content" onSubmit={event=>{event.preventDefault();if(!name.trim())return;onSave({name:name.trim(),teams:selectedTeams});}}>
  <TextInput label="Kundenname" placeholder="z. B. Studio Nord" required autoFocus value={name} onChange={event=>setName(event.currentTarget.value)}/>
  <MultiSelect label="Teams" placeholder="Teams auswählen (optional)" data={teams} value={selectedTeams} onChange={setSelectedTeams}/>
  <Button type="submit" disabled={!name.trim()}>Kunde erstellen</Button>
 </form>;
}
function TeamFilter({team,onChange}:{team:string|null;onChange:(team:string|null)=>void}) {
 return <Menu position="bottom-start" width={240} shadow="md">
  <Menu.Target><Button className="team-filter" variant="subtle" rightSection={<IconChevronDown size={13}/>} aria-label={team?'Team: '+team:'Teams: Alle'}>{team??'Alle'}</Button></Menu.Target>
  <Menu.Dropdown>{[null,...teams].map(value=><Menu.Item key={value??'all'} role="menuitemradio" aria-checked={team===value} rightSection={team===value?<IconCheck size={17}/>:null} onClick={()=>onChange(value)} mih={44}>{value??'Alle'}</Menu.Item>)}</Menu.Dropdown>
 </Menu>;
}
function ProjectRows({onSelect, management = false,items=projects}: {onSelect:(name:string)=>void;management?:boolean;items?:typeof projects}) {
 return <div className="group">{items.map(p=><button className="project-row" key={p.name} onClick={()=>onSelect(p.name)}><span className={'project-mark '+p.color}><IconFolder size={20}/></span><span className="row-copy"><strong>{management ? p.customer : p.name}</strong><small>{management ? p.name : p.customer+' · '+p.activity}</small></span>{management ? <IconChevronRight size={16} className="muted"/> : <IconPlayerPlayFilled size={16} className="accent"/>}</button>)}</div>;
}
function TimeEntries({onSelect}: {onSelect:(name:string)=>void}) {
 return <div className="group">{projects.slice(1).map((p,i)=><button className="time-row" key={p.name} onClick={()=>onSelect(p.name)}><span className={'line-mark '+p.color}/><span className="row-copy"><strong>{p.name}</strong><small>{p.customer} · {i===0?'09:00–10:30':'08:15–09:00'}</small></span><strong className="duration">{i===0?'1:30':'0:45'}</strong><IconChevronRight size={14} className="muted"/></button>)}</div>;
}
function TimerPanel({running,project,onToggle,onSelect}: {running:boolean;project:string;onToggle:()=>void;onSelect:()=>void}) {
 return <section className={'timer-panel '+(!running?'idle':'')}>
   <div className="timer-meta"><span className="live-label">{running && <span className="live-dot"/>}{running?'ZEIT LÄUFT':'BEREIT, WENN DU ES BIST'}</span><span>Nord Studio</span></div>
   <button className="timer-project" onClick={onSelect}>{project}<IconChevronRight size={17}/></button>
   <p className="timer-activity">Entwicklung</p>
   <div className="timer-bottom"><span className="timer-number">{running?'02:24':'00:00'}</span><Button color={running?'red':'brand'} variant={running?'light':'filled'} onClick={onToggle} leftSection={running?<IconSquareFilled size={12}/>:<IconPlayerPlayFilled size={13}/>}>{running?'Stoppen':'Starten'}</Button></div>
 </section>;
}
function ReportView({empty,onEntry}: {empty:boolean;onEntry:(name:string)=>void}) {
 const [period,setPeriod]=useState('Woche');const [week,setWeek]=useState(0);const [filter,setFilter]=useState('Alle Projekte');
 const ranges=['3.–9. November','10.–16. November','17.–23. November'];
 const noData=empty||week!==0;
 return <><SegmentedControl fullWidth value={period} onChange={setPeriod} data={['Tag','Woche','Monat','Jahr']}/>
 <div className="date-nav"><ActionIcon aria-label="Vorheriger Zeitraum" onClick={()=>setWeek(Math.max(-1,week-1))}><IconArrowLeft size={19}/></ActionIcon><strong>{period==='Woche'?ranges[week+1]:period==='Tag'?'Donnerstag, 13. Nov.':period==='Monat'?'November 2025':'2025'}</strong><ActionIcon aria-label="Nächster Zeitraum" onClick={()=>setWeek(Math.min(1,week+1))}><IconArrowRight size={19}/></ActionIcon></div>
 <Select aria-label="Projektfilter" value={filter} onChange={v=>setFilter(v??'Alle Projekte')} data={['Alle Projekte',...projects.map(p=>p.name)]} mb="md"/>
 <section className="report-card"><span className="muted">Erfasste Zeit</span><h2>{noData?'0':filter==='Alle Projekte'?'28':'12'}<small> Std. </small>{noData?'00':filter==='Alle Projekte'?'45':'30'}<small> Min.</small></h2><div className="chart">{[65,80,48,59,0,0,0].map((h,i)=><div className="chart-column" key={i}><div className="bar-track"><div className={'bar '+(i===3?'today-bar':'')} style={{height:noData?'0%':h+'%'}}/></div><span>{['Mo','Di','Mi','Do','Fr','Sa','So'][i]}</span></div>)}</div></section>
 {noData?<EmptyState label="Keine Einträge" detail="Für diesen Zeitraum wurde keine Zeit erfasst."/>:<><SectionTitle title="Zeiteinträge"/><TimeEntries onSelect={onEntry}/></>}
 </>;
}
function EmptyState({label,detail}:{label:string;detail:string}) {return <div className="empty-state"><IconClock size={30} stroke={1.5}/><h3>{label}</h3><p>{detail}</p></div>;}
function SectionTitle({title,action,onClick}:{title:string;action?:string;onClick?:()=>void}) {return <div className="section-title"><h3>{title}</h3>{action&&<Button variant="transparent" size="compact-sm" onClick={onClick}>{action}</Button>}</div>;}

function Phone({initialScreen,state,dark}:{initialScreen:Screen;state:ReviewState;dark:boolean}) {
 const [screen,setScreen]=useState<Screen>(initialScreen);const [running,setRunning]=useState(state==='running'||state==='offline');const [project,setProject]=useState('Mobile App');const [sheet,setSheet]=useState<'entry'|'settings'|'project'|'customer'|null>(null);const [notice,setNotice]=useState('');const [search,setSearch]=useState('');const [team,setTeam]=useState<string|null>(null);
 const [createdCustomers,setCreatedCustomers]=useState<CustomerDraft[]>([]);
 const matchingCustomers=createdCustomers.filter(customer=>(team===null||customer.teams.includes(team))&&customer.name.toLocaleLowerCase('de').includes(search.trim().toLocaleLowerCase('de')));
 const matchingProjects=projects.filter(p=>(team===null||p.teams.includes(team))&&(p.name+' '+p.customer).toLocaleLowerCase('de').includes(search.trim().toLocaleLowerCase('de')));
 const resetFilters=()=>{setTeam(null);setSearch('');};
 const openEntry=(name:string)=>{setProject(name);setSheet('entry');};
 const flash=(message:string)=>setNotice(message);
 return <MantineProvider theme={theme} forceColorScheme={dark?'dark':'light'}><div className={'phone unified'+(dark?' dark':'')}>
 <div className="status-bar"><strong>9:41</strong><span><IconWifi size={16}/><IconBatteryFilled size={22}/></span></div>
 <div className="phone-top">{screen==='Projekte'?<TeamFilter team={team} onChange={setTeam}/>:<span/>}<div><ActionIcon aria-label="Zeiteintrag erstellen" title="Zeiteintrag erstellen" onClick={()=>setSheet('entry')}><IconPlayerPlayFilled size={19}/></ActionIcon><ActionIcon aria-label={state==='offline'?'Offline · 2 Änderungen ausstehend':'Synchronisieren'} title={state==='offline'?'Offline · 2 Änderungen ausstehend':'Synchronisieren'} onClick={()=>flash(state==='offline'?'Offline · 2 Änderungen ausstehend (Simulation).':'Synchronisiert · nur Demo')}>{state==='offline'?<IconCloudOff size={19}/>:<IconRefresh size={19}/>}</ActionIcon><ActionIcon aria-label="Einstellungen" onClick={()=>setSheet('settings')}><IconSettings size={21}/></ActionIcon></div></div>
 <main className="phone-content" aria-label={screen}>
 {notice&&<div className="notice" role="status">{notice}<ActionIcon aria-label="Hinweis schließen" onClick={()=>setNotice('')} size={28}><IconX size={14}/></ActionIcon></div>}
 {screen==='Heute'&&<>
   <TimerPanel running={running} project={project} onSelect={()=>setSheet('project')} onToggle={()=>{setRunning(!running);flash(running?'Zeiteintrag gestoppt · nur lokal simuliert.':'Zeiterfassung gestartet · nur lokal simuliert.');}}/>
   {state==='empty'?<><EmptyState label="Dein Tag beginnt hier" detail="Wähle ein Projekt und erfasse deine erste Zeit."/><Button fullWidth onClick={()=>setSheet('project')}>Projekt auswählen</Button></>:<><SectionTitle title="Zuletzt verwendet" action="Alle" onClick={()=>setScreen('Projekte')}/><ProjectRows onSelect={name=>{setProject(name);setSheet('entry');}}/></>}
 </>}
 {screen==='Projekte'&&<><TextInput placeholder="Kunden oder Projekte suchen" aria-label="Kunden oder Projekte suchen" value={search} onChange={e=>setSearch(e.currentTarget.value)}/><div className="section-title"><h3>Kunden</h3><ActionIcon aria-label="Neuen Kunden erstellen" title="Neuen Kunden erstellen" onClick={()=>setSheet('customer')}><IconPlus size={21}/></ActionIcon></div>{matchingProjects.length+matchingCustomers.length>0?<><ProjectRows management items={matchingProjects} onSelect={name=>{setProject(name);setSheet('project');}}/>{matchingCustomers.length>0&&<div className="group">{matchingCustomers.map((customer,index)=><button className="project-row" key={index} onClick={()=>flash('Dieser Kunde hat noch keine Projekte · Demo.')}><span className="project-mark blue"><IconFolder size={20}/></span><span className="row-copy"><strong>{customer.name}</strong><small>Noch keine Projekte</small></span><IconChevronRight size={16} className="muted"/></button>)}</div>}</>: <div role="status"><EmptyState label="Keine passenden Kunden" detail="Für diese Kombination aus Team und Suche gibt es keine Ergebnisse."/><Button variant="light" fullWidth onClick={resetFilters}>Filter zurücksetzen</Button></div>}</>}
 {screen==='Berichte'&&<ReportView empty={state==='empty'} onEntry={openEntry}/>}
 </main>
 <nav className="tab-bar" aria-label="Hauptnavigation">{([{label:'Heute',Icon:IconClock},{label:'Projekte',Icon:IconFolder},{label:'Berichte',Icon:IconChartBar}] as const).map(({label,Icon})=><button key={label} className={screen===label?'selected':''} aria-current={screen===label?'page':undefined} onClick={()=>{setScreen(label);setNotice('');}}><Icon size={23} stroke={screen===label?2:1.7}/><span>{label}</span></button>)}</nav><div className="home-indicator"/>
 <Modal opened={sheet!==null} onClose={()=>setSheet(null)} title={sheet==='customer'?'Neuer Kunde':sheet==='settings'?'Einstellungen':sheet==='project'?'Projekt auswählen':'Zeiteintrag'} centered radius="lg" size={360}>
 {sheet==='customer'?<NewCustomerForm initialTeam={team} onSave={customer=>{setCreatedCustomers(current=>[...current,customer]);resetFilters();setSheet(null);flash('Kunde erstellt · nur in dieser Demo gespeichert.');}}/>:sheet==='settings'?<div className="sheet-content"><Badge variant="light">Nur Demo</Badge><Select label="Arbeitsbereich" data={['Studio · Kimai','Demo · Kimai']} defaultValue="Studio · Kimai"/><Button variant="light" onClick={()=>flash('Integrationen: Kimai · Beispieldaten')}>Integrationen</Button><p>In der App: Konten, Integrationen, Einführung und Diagnose bleiben erreichbar. Keine echten Kontodaten.</p></div>:sheet==='project'?<div className="sheet-content"><p>Kundenauswahl und Aktivitäten sind hier verkürzt.</p>{projects.map(p=><Button key={p.name} justify="space-between" variant={project===p.name?'light':'subtle'} rightSection={<IconChevronRight size={16}/>} onClick={()=>{setProject(p.name);setSheet('entry');}}>{p.name}</Button>)}</div>:<div className="sheet-content"><Badge variant="light">Simulierter Ablauf</Badge><Select label="Projekt" value={project} onChange={v=>setProject(v??'Mobile App')} data={projects.map(p=>p.name)}/><Select label="Aktivität" defaultValue="Entwicklung" data={['Entwicklung','Konzeption','Administration']}/><TextInput label="Beschreibung" placeholder="Woran hast du gearbeitet?"/><div className="form-pair"><TextInput label="Beginn" type="time" defaultValue="10:45"/><TextInput label="Ende (optional)" type="time"/></div><Button onClick={()=>{setSheet(null);setRunning(true);flash('Eintrag gespeichert · Simulation, keine Serververbindung.');}}>Eintrag speichern</Button><p>Keine Persistenz. Eintragsbearbeitung, Löschung und vollständige Zeitvalidierung sind hier nicht modelliert.</p></div>}
 </Modal>
 </div></MantineProvider>;
}

function App() {
 const params=new URLSearchParams(location.search);
 const [screen,setScreen]=useState<Screen>((['Heute','Projekte','Berichte'].includes(params.get('screen')??'')?params.get('screen'):'Heute') as Screen);
 const [state,setState]=useState<ReviewState>((['running','idle','empty','offline'].includes(params.get('state')??'')?params.get('state'):'running') as ReviewState);
 const [dark,setDark]=useState(params.get('theme')==='dark');
 const update=(key:string,value:string)=>{const url=new URL(location.href);url.searchParams.set(key,value);history.replaceState(null,'',url);};
 return <div className="studio">
 <header className="studio-header"><a className="wordmark" href="./">business<span>ToGo</span><Badge variant="outline" color="gray" size="sm">DESIGN LAB · 09</Badge></a><span className="prototype-label">iOS-Entwurf · keine Produktionsänderungen</span></header>
 <section className="intro"><div><p className="eyebrow">WENIGER OBERFLÄCHE. MEHR ARBEITSFLUSS.</p><h1>Ein klarer Fokus.<br/><span>Ein gemeinsamer Entwurf.</span></h1><p className="intro-copy">Der Timer im Mittelpunkt, kompakte Listen und die Farben der businessToGo-Familie. Ohne große Überschriften und Tageszusammenfassung auf der Startseite.</p></div><aside><span className="recommendation-label">ZUSAMMENGEFÜHRT</span><h3>Quiet Focus · kompakt</h3><p>Die Timer-Betonung aus B trifft auf die kurzen Zeilen und Abstände aus C. Ein Entwurf für Heute, Projekte und Berichte.</p></aside></section>
 <div className="review-controls"><div><span className="control-label">Ansicht</span><SegmentedControl value={screen} onChange={v=>{setScreen(v as Screen);update('screen',v);}} data={['Heute','Projekte','Berichte']}/></div><div><span className="control-label">Zustand</span><Select aria-label="Demozustand" value={state} onChange={v=>{setState(v as ReviewState);update('state',v!);}} data={[{value:'running',label:'Zeit läuft'},{value:'idle',label:'Bereit'},{value:'empty',label:'Leer'},{value:'offline',label:'Offline'}]}/></div><Switch label="Dunkel" checked={dark} onChange={e=>{setDark(e.currentTarget.checked);update('theme',e.currentTarget.checked?'dark':'light');}}/><span className="control-hint">Interaktiver Entwurf · Revision 9</span></div>
 <section className="single-preview" aria-label="Zusammengeführter App-Entwurf"><Phone key={screen+state+dark} initialScreen={screen} state={state} dark={dark}/></section>
 <section className="principles"><div><span>01 / STIL</span><h3>System statt Dekoration</h3><p>Systemschrift, semantische Flächen, echte Listen und dezente Trennlinien statt Hintergrundbildern und Kartenschatten.</p></div><div><span>02 / BEDIENUNG</span><h3>Absichten sichtbar machen</h3><p>Starten und Stoppen beschriften. Mindestens 44 pt große Ziele. Einheitliche SF Symbols in der echten iOS-App.</p></div><div><span>03 / VERTRAUEN</span><h3>Status statt Rätsel</h3><p>Offline ersetzt das Sync-Symbol. Details auf Antippen, Fehler bei Bedarf in Klartext — ohne dauerhafte Statusbanner.</p></div></section>
 <footer className="studio-footer">Browser-Annäherung an iOS, keine nativen Komponenten. Tabler-Icons sind Platzhalter für SF Symbols. Alle Daten und Sync-Zustände sind fiktiv. Neue Timer-Kurzwege benötigen separate Freigabe.</footer>
 {import.meta.env.DEV&&<Agentation/>}
 </div>;
}
createRoot(document.getElementById('root')!).render(<MantineProvider theme={theme}><App/></MantineProvider>);
