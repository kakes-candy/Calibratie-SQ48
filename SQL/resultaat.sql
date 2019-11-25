

-- resultaatquery
select
*
from 
(select 
*
,row_number() over(partition by t.dossier_id order by t.eerste_contact_en_meting, t.test_datum_ingevuld) as rij
from #tmp_trajecten as t
) as dichtstbij 
where dichtstbij.rij = 1
order by dichtstbij.dossier_datum_registratie