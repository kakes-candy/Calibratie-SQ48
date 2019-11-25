

## ---- voorbereiding

# Opzetten ----------------------------------------------------------------

library("RODBC")
library("tidyverse")
library('openssl')
library('rjson')

rm(list = ls())


wd <- "C:/Users/hskadminnkakes/workspace/R/Calibratie SQ48/Project"
datadir <- paste0(wd, '/data/')


# Niet voor in de versiebeheer
secrets <- fromJSON(file = paste0(wd, '/secret.json'))
seed_number <- secrets$seed_number


# Connectie ---------------------------------------------------------------

dbhandle <- odbcDriverConnect('driver={SQL Server};server=HSKWCPMI01;database=ecdReplication;trusted_connection=true')

t <- sqlQuery(dbhandle, read_file('SQL/setup.sql'))



# Constanten --------------------------------------------------------------

vanafdatum <- '2017-01-01'
totenmetdatum <- '2019-11-06'


# Query uitvoeren op database ---------------------------------------------

# Eerst string ophalen en dan met find/replace wat parameters aanpassen
querystring <- read_file('SQL/tijdelijke_tabellen.sql')

querystring <- str_replace_all(querystring, "@param_begindatum", vanafdatum)
querystring <- str_replace_all(querystring, "@param_einddatum", totenmetdatum)

# Dan afvuren op de database
t2 <- sqlQuery(dbhandle, querystring)


sq_48_data <- sqlQuery(dbhandle, read_file("SQL/resultaat.sql"))




# Databse opschonen  ------------------------------------------------------


t <- sqlQuery(dbhandle, read_file("SQL/tear_down.sql"))



# verbreken verbinding ----------------------------------------------------

RODBC::odbcCloseAll()




# Verdere bewerkingen -----------------------------------------------------

SES_tabel <- read_csv2(paste0(datadir, "SES status postcode.csv"), col_names = TRUE, cols(
 pcnr = col_character(),
 statusscore17 = col_double())
)




# status toevoegen op basis van postcode
sq_48_data <- sq_48_data %>% 
 mutate(pcnr =  substr(client_woonadres_postcode, 0 ,4)
        ,dossier_datum_registratie = format(dossier_datum_registratie, format = '%Y-%m-%d')
        ,datum_start_behandeling = format(datum_start_behandeling, format = '%Y-%m-%d')
        ,datum_start_onderzoek = format(datum_start_onderzoek, format = '%Y-%m-%d')
        ,test_datum_ingevuld = format(test_datum_ingevuld, format = '%Y-%m-%d')
        ,diagnose_datum_hoofdclassificatie = format(diagnose_datum_hoofdclassificatie, format = '%Y-%m-%d')
        ) %>% 
 left_join(SES_tabel, by = 'pcnr')

  
# Kolommen selecteren, hernoemen
prepare_for_export <- sq_48_data %>% 
  select(dossier_id
         ,dossier_datum_registratie
         ,traject_status
         ,zorgzwaarte_initieel
         ,zorgzwaarte_actueel
         ,client_id
         ,'SES_status'=  statusscore17
         ,client_leeftijd
         ,client_geslacht
         ,pv_opleiding
         ,pv_leefsituatie
         ,prestatie
         ,prestatie_omschrijving
         ,datum_start_onderzoek
         ,datum_start_behandeling
         ,test_datum_ingevuld
         ,test_score_totaal
         ,test_score_schaal_vijandigheid      
         ,test_score_schaal_agorafobie         
         ,test_score_schaal_angst              
         ,test_score_schaal_cognitieve_klachten
         ,test_score_schaal_depressie          
         ,test_score_schaal_somatische_klachten
         ,test_score_schaal_sociale_fobie      
         ,test_score_schaal_vitaliteit         
         ,test_score_schaal_werk_studie        
         ,test_score_schaal_werkzaam
         ,diagnose_datum_hoofdclassificatie
         ,diagnose_primair
         ,diagnose_2
         ,diagnose_3
         ,diagnose_4
         ,diagnose_5)
  




    
# Dossierid en clientid vervangen door geannonimiseerde strings
set.seed(seed_number)
salt2 <- paste(sample(paste0(1:50, letters), size = 3), collapse = '')


prepare_for_export$dossier_id <- md5(paste0(as.character(prepare_for_export$dossier_id), salt))
prepare_for_export$client_id <- md5(paste0(as.character(prepare_for_export$client_id), salt))



bestandsnaam <- paste0(format(Sys.Date(), format = "%Y-%m-%d"), '_sq_48_data.csv')


write_csv2(prepare_for_export, paste0(datadir, bestandsnaam), na = '')
 
 