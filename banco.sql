-- PAINEL BIRIVET - banco de dados
-- Cole TUDO isto no Supabase (menu "SQL Editor" > "New query") e toque em "Run".
-- Pode rodar mais de uma vez sem problema.

-- 1) Tabela onde ficam todas as informações do painel
create table if not exists public.docs (
  collection text not null,
  id text not null,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (collection, id)
);

-- 2) Segurança: só quem fez login consegue ver e alterar
alter table public.docs enable row level security;
drop policy if exists "equipe le" on public.docs;
drop policy if exists "equipe cria" on public.docs;
drop policy if exists "equipe altera" on public.docs;
drop policy if exists "equipe apaga" on public.docs;
create policy "equipe le" on public.docs for select to authenticated using (true);
create policy "equipe cria" on public.docs for insert to authenticated with check (true);
create policy "equipe altera" on public.docs for update to authenticated using (true) with check (true);
create policy "equipe apaga" on public.docs for delete to authenticated using (true);

-- 2b) A equipe consulta sem login (somente leitura). Estudantes e pagamentos ficam só para o administrador.
drop policy if exists "equipe publica le" on public.docs;
create policy "equipe publica le" on public.docs for select to anon
  using (collection not in ('students','payments'));

-- 3) Atualização ao vivo entre aparelhos
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;

-- 4) Dados iniciais (laboratórios, campanhas e lembretes). Pode editar depois no painel.
insert into public.docs (collection, id, data) values
  ('labs','vetnil','{"name": "Vetnil", "hue": 215, "order": 1}'::jsonb),
  ('labs','perig','{"name": "Perig", "hue": 150, "order": 2}'::jsonb),
  ('labs','petsociety','{"name": "Pet Society", "hue": 30, "order": 3}'::jsonb),
  ('labs','softcare','{"name": "Softcare", "hue": 275, "order": 4}'::jsonb),
  ('labs','dupra','{"name": "Dupra", "hue": 355, "order": 5}'::jsonb),
  ('labs','boehringer','{"name": "Boehringer Ingelheim", "hue": 178, "order": 6}'::jsonb),
  ('labs','outros','{"name": "Outros laboratórios", "hue": 240, "order": 7}'::jsonb),
  ('campaigns','vetnil-pdv','{"labId": "vetnil", "name": "Campanha PDV", "origin": "lab", "cycle": "mensal", "unit": "un.", "targetCount": 10, "requiresGrowth": true, "description": "O laboratório escolheu 10 clientes. Cada cliente tem meta mensal em um produto específico e precisa crescer todos os meses.", "reward": "Ação na loja: um estudante monta o ponto de venda e faz o produto girar.\nBrindes exclusivos: o cliente final que comprar ganha um brinde."}'::jsonb),
  ('campaigns','vetnil-digital','{"labId": "vetnil", "name": "Cliente Digital", "origin": "lab", "cycle": "mensal", "unit": "un.", "targetCount": 0, "requiresGrowth": false, "description": "Parecido com o PDV, mas digital. Acompanhamos o cliente e um estudante faz uma ação no local e posta nas redes sociais.", "reward": "Ação digital com divulgação nas redes: compre tal produto, ganhe um brinde."}'::jsonb),
  ('campaigns','vetnil-balconista','{"labId": "vetnil", "name": "Campanha Balconista (Pará)", "origin": "birivet", "cycle": "trimestral", "unit": "R$", "targetCount": 12, "requiresGrowth": false, "description": "Campanha própria da Birivet, com cerca de 12 clientes no Pará. Cada cliente tem meta anual em Vetnil e confere a meta todo mês.", "reward": "Quem bater a meta ganha a premiação de R$ 1.200 no fim do trimestre."}'::jsonb),
  ('campaigns','petsociety-nacional','{"labId": "petsociety", "name": "Campanha Nacional", "origin": "lab", "cycle": "mensal", "unit": "un.", "targetCount": 0, "requiresGrowth": false, "description": "Campanha direta do laboratório. Há missões para cumprir todo mês e, a cada trimestre, produtos foco para trabalhar. Cobrar sempre os consultores.", "reward": ""}'::jsonb),
  ('campaigns','boehringer-trinca','{"labId": "boehringer", "name": "Ticket médio e Trinca de Ouro", "origin": "lab", "cycle": "mensal", "unit": "R$", "targetCount": 0, "requiresGrowth": false, "description": "Clientes Boehringer devem comprar ticket médio acima de cerca de R$ 2.000 e ter a Trinca de Ouro: Regular, Spectra e Combo.", "reward": ""}'::jsonb)
on conflict (collection, id) do nothing;

-- Lembretes: começam a contar a partir de hoje
insert into public.docs (collection, id, data)
select 'tasks', v.id, (v.js::jsonb || jsonb_build_object('since', to_char(current_date,'YYYY-MM-DD')))
from (values
  ('t-pdv','{"title": "Lançar o resultado do mês no PDV Vetnil (meta e crescimento)", "freq": "mensal", "day": 5, "weekday": 1, "date": "", "labId": "vetnil", "campaignId": "vetnil-pdv", "consultantId": "", "notes": "", "lastDone": ""}'),
  ('t-digital','{"title": "Conferir ações do Cliente Digital Vetnil", "freq": "mensal", "day": 5, "weekday": 1, "date": "", "labId": "vetnil", "campaignId": "vetnil-digital", "consultantId": "", "notes": "", "lastDone": ""}'),
  ('t-balc-mes','{"title": "Conferir a meta do mês dos clientes balconista", "freq": "mensal", "day": 5, "weekday": 1, "date": "", "labId": "vetnil", "campaignId": "vetnil-balconista", "consultantId": "", "notes": "", "lastDone": ""}'),
  ('t-balc-tri','{"title": "Conferir quem ganha a premiação de R$ 1.200", "freq": "tri-fim", "day": 28, "weekday": 1, "date": "", "labId": "vetnil", "campaignId": "vetnil-balconista", "consultantId": "", "notes": "", "lastDone": ""}'),
  ('t-ps-missoes','{"title": "Cobrar dos consultores as missões do mês", "freq": "mensal", "day": 10, "weekday": 1, "date": "", "labId": "petsociety", "campaignId": "petsociety-nacional", "consultantId": "", "notes": "", "lastDone": ""}'),
  ('t-ps-foco','{"title": "Passar os produtos foco do trimestre aos consultores", "freq": "tri-inicio", "day": 3, "weekday": 1, "date": "", "labId": "petsociety", "campaignId": "petsociety-nacional", "consultantId": "", "notes": "", "lastDone": ""}'),
  ('t-boe-mes','{"title": "Conferir ticket médio e Trinca de Ouro dos clientes", "freq": "mensal", "day": 20, "weekday": 1, "date": "", "labId": "boehringer", "campaignId": "boehringer-trinca", "consultantId": "", "notes": "", "lastDone": ""}'),
  ('t-boe-sem','{"title": "Cobrar consultores: clientes sem Trinca de Ouro", "freq": "semanal", "day": 1, "weekday": 1, "date": "", "labId": "boehringer", "campaignId": "boehringer-trinca", "consultantId": "", "notes": "", "lastDone": ""}')
) as v(id, js)
on conflict (collection, id) do nothing;
