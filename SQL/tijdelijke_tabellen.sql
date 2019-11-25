 -- Queries voor het ophalen van data voor calibratie t-score sq-48
 
 
 -- Sessies en producten in tijdelijke tabel
select 
p.dossier_id
,p.product_inzet_fase
,p.product_categorie
,s.sessie_datum_starttijd
,p.product_funding_type
into #tmp_sessies
from dbo.vw_producten as p
left join dbo.vw_sessies as s on p.product_id = s.product_id
where p.product_startdatum between '@param_begindatum' and '@param_einddatum'
and s.sessie_status = 'Uitgevoerd'
and s.sessie_tijd_direct > 0
and s.sessie_datum_starttijd between '@param_begindatum' and '@param_einddatum'




-- sggz trajecten apart voor snelheid
select * into #tmp_sggz from dbo.vw_trajecten_sggz


-- trajectgegevens in tijdelijke tabel
select 
d.dossier_id
,d.dossier_type
,sggz.sggz_productgroep
,bggz.bggz_productgroep_actueel
,case when d.dossier_type = 'bggz' then bggz_productgroep_actueel when d.dossier_type = 'sggz' then sggz.sggz_productgroep else null end as prestatie
,case when d.dossier_type = 'bggz' then bggz.zvz_actueel when d.dossier_type = 'sggz' then sggz.sggz_productgroep_omschrijving else null end as prestatie_omschrijving
,case when d.dossier_type = 'bggz' then bggz.bggz_traject_status when d.dossier_type = 'sggz' then sggz.sggz_traject_status else null end as traject_status
into #tmp_prestaties
from dbo.vw_dossiertype as d
left join #tmp_sggz as sggz on d.dossier_id = sggz.dossier_id
left join dbo.vw_trajecten_bggz as bggz on d.dossier_id = bggz.dossier_id
where d.peildatum between '@param_begindatum' and '@param_einddatum'


--Diagnoses in tijlijke tabel
select 
dossier_id
,diagnose_datum_hoofdclassificatie
,[diagnose_1]
,[diagnose_2]
,[diagnose_3]
,[diagnose_4]
,[diagnose_5] 
into #tmp_diagnoses
from  
(
  select 
  d.dossier_id 
  ,d.diagnose_datum_hoofdclassificatie
  ,d.diagnose_beschrijving_dsm5
  ,concat('diagnose_', row_number() over (partition by d.dossier_id order by d.diagnose_primair desc, diagnose_volgnummer)) as nummer
  from dbo.vw_diagnoses as d
  where d.diagnose_actueel = 1 
  and (d.diagnose_code_dsm4 like 'as1%' or d.diagnose_code_dsm4 like 'as2%')
  and d.diagnose_code_dsm4 <> 'as2_18.02'
  and d.diagnose_invoerdatum between '@param_begindatum' and '@param_einddatum'
) AS SourceTable  
PIVOT  
(  
  MIN(diagnose_beschrijving_dsm5)  
  FOR nummer IN ([diagnose_1], [diagnose_2], [diagnose_3], [diagnose_4], [diagnose_5])  
) AS PivotTable;



-- Afnames vragenlijsten (sq48) in tabel
select 
schaalscores.*
,v.test_score
into #tmp_scores
from dbo.vw_vragenlijsten as v 
inner join (
SELECT dossier_id,test_datum_ingevuld, test_id,
[COGN: Cognitieve klachten], 
[ANXI: Angst], 
[WORK: Werk / studie], 
[VITA: Vitaliteit / optimisme], 
[AGOR: Agorafobie], 
[MOOD: Depressie], 
[SOMA: Somatische klachten], 
[AGGR: Vijandigheid], 
[SOPH: Sociale fobie], 
[Werkzaam]
FROM  
(
select
sc.dossier_id
,sc.test_id
,sc.test_datum_ingevuld
,sc.schaal_naam
,convert(int, sc.schaal_score) as schaal_score
from dbo.vw_vragenlijsten_schaalscore as sc 
where sc.test_afkorting_naam = 'SQ-48'
and sc.test_datum_ingevuld between '@param_begindatum' and '@param_einddatum'
) AS brontabel  
PIVOT  
(  
AVG(schaal_score)  
FOR schaal_naam IN (
[COGN: Cognitieve klachten], 
[ANXI: Angst], 
[WORK: Werk / studie], 
[VITA: Vitaliteit / optimisme], 
[AGOR: Agorafobie], 
[MOOD: Depressie], 
[SOMA: Somatische klachten], 
[AGGR: Vijandigheid], 
[SOPH: Sociale fobie], 
[Werkzaam])  
) AS PivotTable
) as schaalscores on v.test_id = schaalscores.test_id
where v.test_naam = 'sq-48' and v.test_datum_ingevuld is not null
order by schaalscores.dossier_id


-- trajecen en tussentijdse tabellen bij elkaar
select 
d.dossier_id
,d.dossier_datum_registratie
,d.dossier_status
,case when pt.traject_status <> 'Open' then 'Gesloten' else pt.traject_status end as traject_status
,d.client_id
,cl.client_woonadres_postcode
,dbo.Leeftijd(cl.client_geboortedatum, getdate()) as client_leeftijd
,cl.client_geslacht
,pv_opleiding
,pv_leefsituatie
,case when pt.traject_status = 'Open' then null else pt.prestatie end as prestatie
,case when pt.traject_status = 'Open' then null else pt.prestatie_omschrijving end as prestatie_omschrijving
,dt.zorgzwaarte_initieel
,dt.zorgzwaarte_actueel
,onderzoek_uitgevoerd.datum_start_onderzoek
,behandeling_uitgevoerd.datum_start_behandeling
,ABS(datediff(day, case when onderzoek_uitgevoerd.datum_start_onderzoek < behandeling_uitgevoerd.datum_start_behandeling then onderzoek_uitgevoerd.datum_start_onderzoek else behandeling_uitgevoerd.datum_start_behandeling end, score.test_datum_ingevuld)) as eerste_contact_en_meting
,score.test_datum_ingevuld
,score.[AGGR: Vijandigheid] as test_score_schaal_vijandigheid
,score.[AGOR: Agorafobie] as test_score_schaal_agorafobie 
,score.[ANXI: Angst] as test_score_schaal_angst
,score.[COGN: Cognitieve klachten] as test_score_schaal_cognitieve_klachten
,score.[MOOD: Depressie] as test_score_schaal_depressie
,score.[SOMA: Somatische klachten] as test_score_schaal_somatische_klachten
,score.[SOPH: Sociale fobie] as test_score_schaal_sociale_fobie
,score.[VITA: Vitaliteit / optimisme] as test_score_schaal_vitaliteit
,score.[WORK: Werk / studie] as test_score_schaal_werk_studie
,score.Werkzaam as test_score_schaal_werkzaam
,convert(int, score.test_score) as test_score_totaal
,diag.diagnose_datum_hoofdclassificatie
,diag.diagnose_1 as diagnose_primair
,diag.diagnose_2
,diag.diagnose_3
,diag.diagnose_4
,diag.diagnose_5
into #tmp_trajecten
from dbo.vw_dossiers as d
left join #tmp_prestaties as pt on d.dossier_id = pt.dossier_id
left join dbo.vw_dossiertype as dt on d.dossier_id = dt.dossier_id
left join dbo.vw_client as cl on d.client_id = cl.client_id
left join dbo.tmp_pv_resultaten as pv on pv.dossier_id = d.dossier_id
left join #tmp_diagnoses as diag on d.dossier_id = diag.dossier_id
inner join (
select 
s.dossier_id
,min(s.sessie_datum_starttijd) as datum_start_onderzoek
from #tmp_sessies as s
where s.product_inzet_fase = 'Onderzoek'
and s.product_categorie = 'Onderzoek'
group by s.dossier_id 
having count(1) > 0
) as onderzoek_uitgevoerd on d.dossier_id = onderzoek_uitgevoerd.dossier_id
inner join (
select 
s.dossier_id
,min(s.sessie_datum_starttijd) as datum_start_behandeling
from #tmp_sessies as s
where s.product_funding_type in ('bggz', 'sggz')
and s.product_inzet_fase = 'Behandeling'
and s.product_categorie = 'Behandeling' 
group by s.dossier_id 
having count(1) > 0
) as behandeling_uitgevoerd on d.dossier_id = behandeling_uitgevoerd.dossier_id
inner join #tmp_scores as score on score.dossier_id = d.dossier_id
where d.dossier_datum_aanmeld between '@param_begindatum' and '@param_einddatum'
-- and d.dossier_type in ('bggz', 'sggz')
and d.dossier_vestiging <> 'ZZBewaren'


-- resultaat wordt apart opgehaald




