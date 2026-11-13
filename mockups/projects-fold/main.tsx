import React, { useState } from 'react';
import { createRoot } from 'react-dom/client';
import { MantineProvider, createTheme, TextInput } from '@mantine/core';
import { IconFolder, IconChevronRight, IconChevronDown, IconChevronLeft, IconPlus, IconSearch, IconClock, IconLayoutGrid, IconChartBar, IconSettings } from '@tabler/icons-react';
import { Agentation } from 'agentation';
import '@mantine/core/styles.css';
import './styles.css';

type Project = { name: string; color: string };
const customers = [
  { name: 'Acme GmbH', color: '#397dba', projects: [{ name: 'Website Relaunch', color: '#b568aa' }, { name: 'Beratung', color: '' }] },
  { name: 'BlueCat Bio', color: '#348c79', projects: [{ name: 'Plattform', color: '#348c79' }] },
  { name: 'Studio Nord', color: '', projects: [{ name: 'Design', color: '' }] },
];
function FolderRow({ name, color, subtitle, expanded, onClick }: { name: string; color: string; subtitle?: string; expanded?: boolean; onClick: () => void }) {
  return <button className="row" onClick={onClick}><IconFolder size={21} color={color || '#666'} stroke={1.8}/><span className="row-text">{name}{subtitle && <small>{subtitle}</small>}</span>{expanded ? <IconChevronDown className="chevron" size={18}/> : <IconChevronRight className="chevron" size={18}/>}</button>;
}
function App() {
  const variant = 2;
  const [selected, setSelected] = useState<number | null>(null);
  const [opened, setOpened] = useState<string[]>([]);
  const [query, setQuery] = useState('');
  const [detail, setDetail] = useState('');
  const customer = selected === null ? null : customers[selected];
  const openProject = (p: Project) => setDetail(p.name);
  const search = query.trim().toLowerCase();
  const filtered = customers.map(c => ({ ...c, projects: !search || c.name.toLowerCase().includes(search) ? c.projects : c.projects.filter(p => p.name.toLowerCase().includes(search)) })).filter(c => !search || c.name.toLowerCase().includes(search) || c.projects.length > 0);
  return <div className="layout"><aside><h2>Projects grouped by customer</h2><p>Customers start collapsed. Tap a customer to reveal projects; search reveals matching projects. The plus still adds a project.</p><p className="note">Sample interactions only. Customer and project editing, deletion and creation are not implemented here.</p></aside><main className="phone"><div className="status"><b>9:41</b><span>● ● ▰</span></div><header>{(customer || detail) && <button className="back" onClick={() => detail ? setDetail('') : setSelected(null)}><IconChevronLeft size={20}/>{detail && customer ? customer.name : 'Projects'}</button>}{(detail || customer) && <h1>{detail || customer?.name}</h1>}</header>
    {detail ? <div className="placeholder">Project details (placeholder)</div> : customer ? <><div className="new-project"><input placeholder="New Project"/><button aria-label="Projekt hinzufügen"><IconPlus size={20}/></button></div><div className="card">{customer.projects.map(p => <FolderRow key={p.name} name={p.name} color={p.color} onClick={() => openProject(p)}/>)}</div></> : <><div className="search-line"><div className="search"><TextInput placeholder="Kunden oder Projekte suchen" leftSection={<IconSearch size={17}/>} value={query} onChange={e => setQuery(e.currentTarget.value)}/></div><button className="new-customer" aria-label="Neuen Kunden erstellen"><IconPlus size={20}/></button></div>
    {variant === 2 ? <div className="groups">{filtered.map(c => <section key={c.name} className="group"><div className="customer-row"><button className="customer-toggle" aria-expanded={opened.includes(c.name) || !!search} onClick={() => setOpened(opened.includes(c.name) ? opened.filter(n => n !== c.name) : [...opened, c.name])}><IconFolder size={21} color={c.color || '#666'} stroke={1.8}/><span>{c.name}</span>{opened.includes(c.name) || search ? <IconChevronDown size={18}/> : <IconChevronRight size={18}/>}</button><button aria-label={`Projekt für ${c.name} hinzufügen`}><IconPlus size={18}/></button></div>{(opened.includes(c.name) || !!search) && <div className="card">{c.projects.map(p => <FolderRow key={p.name} name={p.name} color={p.color} onClick={() => openProject(p)}/>)}</div>}</section>)}</div> : <div className="card">{filtered.map(c => <React.Fragment key={c.name}><FolderRow name={c.name} color={c.color} subtitle={variant === 1 && c.projects.length === 1 ? c.projects[0].name : `${c.projects.length} ${c.projects.length === 1 ? 'Projekt' : 'Projekte'}`} expanded={variant === 0 && opened.includes(c.name)} onClick={() => variant === 0 ? setOpened(opened.includes(c.name) ? opened.filter(n => n !== c.name) : [...opened, c.name]) : c.projects.length === 1 ? openProject(c.projects[0]) : setSelected(customers.indexOf(c))}/>{variant === 0 && opened.includes(c.name) && <div className="children">{c.projects.map(p => <FolderRow key={p.name} name={p.name} color={p.color} onClick={() => openProject(p)}/>)}</div>}</React.Fragment>)}</div>}</>}
    <nav><div><IconClock/>Today</div><div className="active"><IconLayoutGrid/>Projects</div><div><IconChartBar/>Reports</div><div><IconSettings/>Settings</div></nav></main></div>;
}
createRoot(document.getElementById('root')!).render(<MantineProvider theme={createTheme({fontFamily:'-apple-system, BlinkMacSystemFont, sans-serif', primaryColor:'teal', defaultRadius:'md'})}><App/>{import.meta.env.DEV && <Agentation/>}</MantineProvider>);
