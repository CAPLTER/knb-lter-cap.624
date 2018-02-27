# libraries ----
library('RPostgreSQL')
library("RMySQL")
library("devtools")
library('plyr') # always load plyr before dplyr
library("dplyr")
library("tidyr")
library("reshape2")
# library("EML")
library("rapportools")

# DB connections ----
pg <- dbConnect(dbDriver("PostgreSQL"),
                user="srearl",
                dbname="working",
                host="localhost",
                password=.rs.askForPassword("Enter password:"))

pg <- dbConnect(dbDriver("PostgreSQL"),
                user="srearl",
                dbname="caplter",
                host="stegosaurus.gios.asu.edu",
                password=.rs.askForPassword("Enter password:"))

# datasets----
# data from 2007 (single storm at IBW) omitted owing to lack of times
# 61 values sans an analysis id are omitted
runoffChemistry <- dbGetQuery(pg,
"SELECT
  s.bottle,
  sites.abbreviation AS runoff_location,
  s.sample_datetime AS runoff_datetime,
  r.replicate,
  a.analysis_name AS analysis,
  r.concentration,
  dq.data_qualifier_label AS data_qualifier,
  r.comments
FROM stormwater.results r
  JOIN stormwater.samples s ON (s.sample_id = r.sample_id)
  JOIN stormwater.analysis a ON (r.analysis_id = a.analysis_id)
  JOIN stormwater.sites ON (s.site_id = sites.site_id)
  LEFT JOIN stormwater.data_qualifier dq ON (dq.data_qualifier_id = r.data_qualifier)
WHERE
  EXTRACT (YEAR FROM s.sample_datetime) > 2007 AND
  r.analysis_id IS NOT NULL AND
  (bottle NOT ILIKE '%rain%' OR bottle IS NULL)
;")

# need to add a definitive reference for whether a sample is a blank given that bottle is omitted (and confusing)
runoffChemistry <- runoffChemistry %>% mutate(blank = as.factor(ifelse(grepl('blk|blank', bottle, ignore.case = T), 'TRUE', 'FALSE'))) %>%
                                       select(-bottle)

rainfallChemistry <- dbGetQuery(pg,
"SELECT
  sites.abbreviation AS rain_location,
  s.sample_datetime AS rain_datetime,
  r.replicate,
  a.analysis_name AS analysis,
  r.concentration,
  dq.data_qualifier_label AS data_qualifier,
  r.comments
FROM stormwater.results r
  JOIN stormwater.samples s ON (s.sample_id = r.sample_id)
  JOIN stormwater.analysis a ON (r.analysis_id = a.analysis_id)
  JOIN stormwater.sites ON (s.site_id = sites.site_id)
  LEFT JOIN stormwater.data_qualifier dq ON (dq.data_qualifier_id = r.data_qualifier)
WHERE
  EXTRACT (YEAR FROM s.sample_datetime) > 2007 AND
  r.analysis_id IS NOT NULL AND
  bottle ILIKE '%rain%'
ORDER BY sites.abbreviation, s.sample_datetime, a.analysis_name
;")

# cast...this was the plan but did not think about comments and data qualifiers, which render casting not impossible but really impractial for this dataset
# alpha <- dcast(results, result_id + abbreviation + sample_datetime + data_qualifier_label + comments ~ analysis_name, value.var = 'concentration')
# beta <- spread(results, analysis_name, concentration)

rainfall <- dbGetQuery(pg,
"SELECT
  sites.abbreviation AS rain_location,
  r.event_datetime AS rain_datetime,
  r.rainfall_quantity AS rain_quantity
FROM stormwater.rainfall r
  JOIN stormwater.sites ON (r.site_id = sites.site_id)
;")

discharge <- dbGetQuery(pg,
"SELECT
  sites.abbreviation AS discharge_location,
  r.event_datetime AS discharge_datetime,
  r.water_height AS water_height,
  r.discharge AS raw_discharge,
  r.discharge_corrected AS edited_discharge
FROM stormwater.discharge r
  JOIN stormwater.sites ON (r.site_id = sites.site_id)
;")

# pulled these data for Nancy in August 2016. Though not included in the initial
# pull for publication, it may be that the sample/bottle ID should be included.
# Revisit this when you update the published data.
particulates <- dbGetQuery(pg,
"SELECT
  sites.abbreviation AS particle_location,
  s.sample_datetime AS particle_datetime,
  r.replicate AS replicate,
  r.filter_initial AS filter_wt,
  r.filter_dry AS filter_dry_wt,
  r.volume_filtered AS vol_filtered,
  r.filter_ashed AS filter_ash_wt,
  r.data_qualifier AS data_qualifier,
  r.comments AS comments
FROM stormwater.solids r
  JOIN stormwater.samples s ON (s.sample_id = r.sample_id)
  JOIN stormwater.sites ON (s.site_id = sites.site_id)
  LEFT JOIN stormwater.data_qualifier dq ON (dq.data_qualifier_id = r.data_qualifier)
;")

samplingLocation <- dbGetQuery(pg,
"SELECT
  abbreviation AS short_code,
  site_name AS name,
  latitude,
  longitude
FROM stormwater.sites
;")

analyses <- dbGetQuery(pg,
"SELECT
  DISTINCT ON (analysis_name)
  analysis_name as analysis,
  analysis_description AS description,
  units,
  instrument
FROM stormwater.analysis
RIGHT JOIN stormwater.results r ON (r.analysis_id = analysis.analysis_id)
WHERE analysis_name IS NOT NULL
;")

# address column names
colnames(runoffChemistry) <- tocamel(colnames(runoffChemistry))
colnames(rainfallChemistry) <- tocamel(colnames(rainfallChemistry))
colnames(rainfall) <- tocamel(colnames(rainfall))
colnames(discharge) <- tocamel(colnames(discharge))
colnames(particulates) <- tocamel(colnames(particulates))
colnames(samplingLocation) <- tocamel(colnames(samplingLocation))
colnames(analyses) <- tocamel(colnames(analyses))

# change dates to chr
rainfallChemistry$rainDatetime <- format(rainfallChemistry$rainDatetime, format = '%Y-%m-%d') # also remove time
runoffChemistry$runoffDatetime <- format(runoffChemistry$runoffDatetime, "%Y-%m-%d %H:%M:%S")
discharge$dischargeDatetime <- format(discharge$dischargeDatetime, "%Y-%m-%d %H:%M:%S")
particulates$particleDatetime <- format(particulates$particleDatetime, "%Y-%m-%d %H:%M:%S")
rainfall$rainDatetime <- format(rainfall$rainDatetime, "%Y-%m-%d %H:%M:%S")

# cols to be categories as
runoffChemistry$runoffLocation <- as.factor(runoffChemistry$runoffLocation)
rainfallChemistry$rainLocation <- as.factor(rainfallChemistry$rainLocation )
runoffChemistry$analysis <- as.factor(runoffChemistry$analysis)
rainfallChemistry$analysis <- as.factor(rainfallChemistry$analysis)
rainfall$rainLocation <- as.factor(rainfall$rainLocation)
discharge$dischargeLocation <- as.factor(discharge$dischargeLocation)
particulates$particleLocation <- as.factor(particulates$particleLocation)

# particulates dataQualifier is empty, need to change it to chr as it defaulted to int
particulates$dataQualifier <- as.character(particulates$dataQualifier)

# some fields have commas. Ultimately, this should be rectified in the database but address here for now. Note that the data qualifier table needs editing
analyses$description <- gsub(",", " ", analyses$description)
rainfallChemistry$dataQualifier <- gsub(",", " ", rainfallChemistry$dataQualifier)
runoffChemistry$dataQualifier <- gsub(",", " ", runoffChemistry$dataQualifier)
runoffChemistry$comments <- gsub(",", " ", runoffChemistry$comments)

# generate column definitions ----
col.defs.runoffChemistry <- c(
  'chemLocation' = 'location short code (reference location details in samplingLocation table)',
  'chemDatetime' = 'collection date and time',
  'replicate' = 'sample replicate number',
  'analysis' = 'analyte quantified (reference analysis details in the analyses table',
  'concentration' = 'concentration of analyte',
  'dataQualifier' = 'data qualifier flag',
  'comments' = 'comments regarding sample',
  'blank' = 'boolean value (TRUE or FALSE) indicating whether the sample is a blank')

col.defs.rainfallChemistry <- c(
  'rainLocation' = 'location short code (reference location details in samplingLocation table)',
  'rainDatetime' = 'collection date and time',
  'replicate' = 'sample replicate number',
  'analysis' = 'analyte quantified (reference analysis details in the analyses table',
  'concentration' = 'concentration of analyte',
  'dataQualifier' = 'data qualifier flag',
  'comments' = 'comments regarding sample')

col.defs.rainfall <- c(
  'rainLocation' = 'location short code (reference location details in samplingLocation table)',
  'rainDatetime' = 'measurement date and time',
  'rainQuantity' = 'precipitation amount')

col.defs.discharge <- c(
  'dischargeLocation' = 'location short code (reference location details in samplingLocation table)',
  'dischargeDatetime' = 'measurement date and time',
  'waterHeight' = 'water height above sensor',
  'rawDischarge' = 'discharge (Q) estimated from Manning equation',
  'editedDischarge' = 'corrections to rawDischarge')

col.defs.particulates <- c(
  'particleLocation' = 'location short code (reference location details in samplingLocation table)',
  'particleDatetime' = 'measurement date and time',
  'replicate' = 'sample replicate number',
  'filterWt' = 'weight of clean, ashed filter',
  'filterDryWt' = 'dry filter weight',
  'volFiltered' = 'volume of sample filtered',
  'filterAshWt' = 'ashed weight of filter',
  'dataQualifier' = 'data qualifier flag',
  'comments' = 'comments regarding sample')

col.defs.samplingLocation <- c(
  'shortCode' = 'location short code',
  'name' = 'name of sampling location',
  'latitude' = 'latitude of sampling location',
  'longitude' = 'longitude of sampling location')

col.defs.analyses <- c(
  'analysis' = 'analyte quantified',
  'description' = 'analyte description',
  'units' = 'unit of measure',
  'instrument' = 'analytical instrument')

# generate unit definitions----
unit.defs.runoffChemistry <- list(
  'runoffLocation' = c("IBW" = "Indian Bend Wash",
                     "BV" = "Bella Vista",
                     "CB" = "Camelback",
                     "ENC" = "Encantada",
                     "KP" = "Kiwanis Park",
                     "LM" = "Lake Marguerite",
                     "MR" = "Martin Residence",
                     "MS" = "Montessori",
                     "PIE" = "Pierce",
                     "SGC" = "Silverado Golf Course",
                     "SW" = "Sweetwater"),
  'runoffDatetime' = c(format = 'YYYY-MM-DD HH:MM:SS'),
  'replicate' = 'number',
  'analysis' = c("CaD_FLAME_AA" = "Dissolved Calcium (FLAME AA)",
                 "CaD_ICP" = "Dissolved Calcium (ICP)",
                 "ClD_LACHAT" = "Dissolved Chloride (LACHAT)",
                 "DOC_TOC" = "Dissolved organic carbon in mg/l",
                 "KD_ICP" = "Dissolved Potassium (ICP)",
                 "MgD_ICP" = "Dissolved Magnesium (ICP)",
                 "NaD_ICP" = "Dissolved Sodium (ICP)",
                 "NH4_LACHAT" = "Ammonium (LACHAT), reported as mgN/l",
                 "NiD_ICP" = "dissolved nickel (ICP-OES)",
                 "NO2D_LACHAT" = "Dissolved Nitrite (LACHAT) reported as mg/L",
                 "NO3D_IC" = "Dissolved nitrate (IC), reported as mgN/l",
                 "NO3D_LACHAT" = "Dissolved Nitrate (LACHAT), reported as mgN/l",
                 "NO3T_AQ2" = "total nitrogen (AQ2)",
                 "NO3T_TOC_TN" = "Total Nitrogen by combustion analysis TOC/TN, final value is mgN/L",
                 "NO3T_TRAACS" = "Total dissolved Nitrogen (TRAACS), NH4, NO3 and DON are oxidized to NO3 and measured all together, final value is mg N/l",
                 "PbD_ICP" = "dissolved lead (ICP-OES)",
                 "PO4D_LACHAT" = "Dissolved phosphorus (LACHAT), reported as ugP/l",
                 "PO4T_AQ2" = "total phosphorus (AQ2)",
                 "PO4T_LACHAT" = "Total phosphorus (LACHAT), reported as ugP/l",
                 "PO4T_TRAACS" = "Total phosphorus (TRAACS), reported as ugP/l",
                 "SO4D_IC" = "Dissolved sulfate (IC), reported as conc. SO4/l",
                 "ZnD_ICP" = "dissolved zinc (ICP-OES)"),
  'concentration' = 'milligramsPerLiter',
  'dataQualifier' = 'data qualifier flag',
  'comments' = 'comments regarding sample',
  'blank' = c('TRUE' = 'indicates sample is a blank',
              'FALSE' = 'indicates sample is not a blank'))

unit.defs.rainfallChemistry <- list(
  'rainfallLocation' = c("IBW" = "Indian Bend Wash",
                     "BV" = "Bella Vista",
                     "CB" = "Camelback",
                     "ENC" = "Encantada",
                     "KP" = "Kiwanis Park",
                     "LM" = "Lake Marguerite",
                     "MR" = "Martin Residence",
                     "MS" = "Montessori",
                     "PIE" = "Pierce",
                     "SGC" = "Silverado Golf Course",
                     "SW" = "Sweetwater"),
  'rainfallDatetime' = c(format = 'YYYY-MM-DD'),
  'replicate' = 'number',
  'analysis' = c("CaD_ICP" = "Dissolved Calcium (ICP)",
                 "ClD_LACHAT" = "Dissolved Chloride (LACHAT)",
                 "PO4D_LACHAT" = "Dissolved phosphorus (LACHAT), reported as ugP/l",
                 "PO4T_TRAACS" = "Total phosphorus (TRAACS), reported as ugP/l",
                 "DOC_TOC" = "Dissolved organic carbon in mg/l",
                 "NO3T_TOC_TN" = "Total Nitrogen by combustion analysis TOC/TN, final value is mgN/L",
                 "NO3T_TRAACS" = "Total dissolved Nitrogen (TRAACS), NH4, NO3 and DON are oxidized to NO3 and measured all together, final value is mg N/l",
                 "NaD_ICP" = "Dissolved Sodium (ICP)",
                 "ZnD_ICP" = "dissolved zinc (ICP-OES)",
                 "NH4_LACHAT" = "Ammonium (LACHAT), reported as mgN/l",
                 "NO3D_LACHAT" = "Dissolved Nitrate (LACHAT), reported as mgN/l"),
  'concentration' = 'milligramsPerLiter',
  'dataQualifier' = 'data qualifier flag',
  'comments' = 'comments regarding sample')

unit.defs.rainfall <- list(
  'rainLocation' = c("BV" = "Bella Vista",
                     "ENC" = "Encantada",
                     "KP" = "Kiwanis Park",
                     "MR" = "Martin Residence",
                     "MS" = "Montessori",
                     "SW" = "Sweetwater"),
  'rainDatetime' = c(format = 'YYYY-MM-DD HH:MM:SS'),
  'rainQuantity' = 'millimeter')

unit.defs.discharge <- list(
  'dischargeLocation' = c("BV" = "Bella Vista",
                          "ENC" = "Encantada",
                          "KP" = "Kiwanis Park",
                          "LM" = "Lake Marguerite",
                          "MR" = "Martin Residence",
                          "MS" = "Montessori",
                          "PIE" = "Pierce",
                          "SGC" = "Silverado Golf Course",
                          "SW" = "Sweetwater"),
  'dischargeDatetime' = c(format = 'YYYY-MM-DD HH:MM:SS'),
  'waterHeight' = 'meter',
  'rawDischarge' = 'litersPerSecond',
  'editedDischarge' = 'litersPerSecond')

unit.defs.particulates <- list(
  'particleLocation' = c("IBW" = "Indian Bend Wash",
                         "BV" = "Bella Vista",
                         "CB" = "Camelback",
                         "ENC" = "Encantada",
                         "KP" = "Kiwanis Park",
                         "LM" = "Lake Marguerite",
                         "MR" = "Martin Residence",
                         "MS" = "Montessori",
                         "PIE" = "Pierce",
                         "SGC" = "Silverado Golf Course",
                         "SW" = "Sweetwater"),
  'particleDatetime' = c(format = 'YYYY-MM-DD HH:MM:SS'),
  'replicate' = 'number',
  'filterWt' = 'gram',
  'filterDryWt' = 'gram',
  'volFiltered' = 'milliliter',
  'filterAshWt' = 'gram',
  'dataQualifier' = 'data qualifier flag',
  'comments' = 'comments regarding sample')

unit.defs.samplingLocation <- list(
  'shortCode' = 'location short code',
  'name' = 'name of sampling location',
  'latitude' = 'meter',
  'longitude' = 'meter')

unit.defs.analyses <- list(
  'analysis' = 'analyte quantified',
  'description' = 'analyte description',
  'units' = 'unit of measure',
  'instrument' = 'analytical instrument')

# generate eml data tables ----
runoffChemistry.DT <- eml_dataTable(runoffChemistry,
                                    name = 'runoffChemistry',
                                    filename = 'runoffChemistry.csv',
                                    col.defs = col.defs.runoffChemistry,
                                    unit.defs = unit.defs.runoffChemistry,
                                    description = 'stormwater runoff chemistry during runoff-generating storms at CAP LTER stormwater sampling sites',
                                    additionalInfo = 'Julie Ann Wrigley Global Institute of Sustainability Informatics processed this data object with the following actions: replace empty or NULL values with NA')

rainfallChemistry.DT <- eml_dataTable(rainfallChemistry,
                                      name = 'rainfallChemistry',
                                      filename = 'rainfallChemistry.csv',
                                      col.defs = col.defs.rainfallChemistry,
                                      unit.defs = unit.defs.rainfallChemistry,
                                      description = 'water chemistry of collected rainfall at CAP LTER stormwater sampling sites',
                                      additionalInfo = 'Julie Ann Wrigley Global Institute of Sustainability Informatics processed this data object with the following actions: replace empty or NULL values with NA')

rainfall.DT <- eml_dataTable(rainfall,
                             name = 'rainfall',
                             filename = 'rainfall.csv',
                             col.defs = col.defs.rainfall,
                             unit.defs = unit.defs.rainfall,
                             description = 'depth of precipitation as measured by tipping bucket rain gauge at CAP LTER stormwater sampling sites',
                             additionalInfo = 'Julie Ann Wrigley Global Institute of Sustainability Informatics processed this data object with the following actions: replace empty or NULL values with NA')

discharge.DT <- eml_dataTable(discharge,
                              name = 'discharge',
                              filename = 'discharge.csv',
                              col.defs = col.defs.discharge,
                              unit.defs = unit.defs.discharge,
                              description = 'discharge at CAP LTER stormwater sampling sites',
                              additionalInfo = 'Julie Ann Wrigley Global Institute of Sustainability Informatics processed this data object with the following actions: replace empty or NULL values with NA')

particulates.DT <- eml_dataTable(particulates,
                                 name = 'particulates',
                                 col.defs = col.defs.particulates,
                                 unit.defs = unit.defs.particulates,
                                 description = 'mass of particulates in stormwater during runoff-generating storms at CAP LTER stormwater sampling sites',
                                 additionalInfo = 'Julie Ann Wrigley Global Institute of Sustainability Informatics processed this data object with the following actions: replace empty or NULL values with NA')

samplingLocation.DT <- eml_dataTable(samplingLocation,
                                     name = 'samplingLocation',
                                     filename = 'samplingLocation.csv',
                                     col.defs = col.defs.samplingLocation,
                                     unit.defs = unit.defs.samplingLocation,
                                     description = 'catalog of CAP LTER stormwater sampling locations',
                                     additionalInfo = 'Julie Ann Wrigley Global Institute of Sustainability Informatics processed this data object with the following actions: replace empty or NULL values with NA')

analyses.DT <- eml_dataTable(analyses,
                             name = 'analyses',
                             filename = 'analyses.csv',
                             col.defs = col.defs.analyses,
                             unit.defs = unit.defs.analyses,
                             description = 'catalog of water chemistry analytes measured as part of CAP LTER stormwater monitoring',
                             additionalInfo = 'Julie Ann Wrigley Global Institute of Sustainability Informatics processed this data object with the following actions: replace empty or NULL values with NA')

# things that will change with each dataset ----
alternateIdentifier <- '624_0'
pubDate <- '2016-01-04'
title <- 'Stormwater runoff and water quality in urbanized watersheds of the greater Phoenix metropolitan area'

abstract <- 'need a project description'

keys <- eml_keyword(list(
"creator defined key word set" = c("nutrients",
                                   "nitrogen",
                                   "phosphorus",
                                   "carbon",
                                   "stormwater",
                                   "urban",
                                   "runoff",
                                   "watershed",
                                   "particulate"),
"LTER core areas" = c("disturbance patterns",
                      "movement of organic matter",
                      "movement of inorganic matter"),
"CAPLTER Keyword Set List" = c("cap lter",
                               "cap",
                               "caplter",
                               "central arizona phoenix long term ecological research",
                               "arizona",
                               "az",
                               "arid land")))

distribution <- new('distribution')
distribution@online@url <- 'http://data.gios.asu.edu/cap/HarvestListFileShow.php?id=624'
distribution@online@onlineDescription = 'CAPLTER Metadata URL'

creator <- c(as('Nancy Grimm', 'creator'),
             as('Stevan Earl', 'creator'),
             as('Rebecca Hale', 'creator'),
             as('Laura Turnbull', 'creator'))

stevanEarl <- new('metadataProvider')
stevanEarl@individualName@givenName <- 'Stevan'
stevanEarl@individualName@surName <- 'Earl'

rebeccaHale <- new('metadataProvider')
rebeccaHale@individualName@givenName <- 'Rebecca'
rebeccaHale@individualName@surName <- 'Hale'

lauraTurnbull <- new('metadataProvider')
lauraTurnbull@individualName@givenName <- 'Laura'
lauraTurnbull@individualName@surName <- 'Turnbull'

metadataProvider <-c(as(stevanEarl, 'metadataProvider'),
                     as(rebeccaHale, 'metadataProvider'),
                     as(lauraTurnbull, 'metadataProvider'))

# methods <- new('methods', methodStep = c(new('methodStep', description = 'The land cover mapping methods were mainly based on the expert knowledge decision rule set and incorporated the GIS vector layer as auxiliary data. The classification rule was established on a hierarchical image object network, and the land use and land cover (LULC) types were classified at three levels accordingly. Image object segmentations and classification are based on their characteristics, such as spectral, spatial, contextual, and geometrical aspects. Classification results include (1) 12 classes for the first level land cover map, (2) 15 classes for the second level of LULC map, and (3) 21 classes for the third LULC classes.')))

# methods <- new('methods', methodStep = c(new('methodStep', description = 'firstStep!')), new('methodStep', description = 'secondStep!'))

# note that dates must have a begin and end
coverage <- eml_coverage(dates = c('2008-01-29', '2015-09-01'),
                         geographic_description = 'CAP LTER study area',
                         NSEWbox = c(+33.6618, +33.4382, -111.856, -112.044)) # here based on extents of (functional) ibw watershed

# things that are less likely to change

giosAddress <- new('address',
                   deliveryPoint = 'PO Box 875402',
                   city = 'Tempe',
                   administrativeArea = 'AZ',
                   postalCode = '85287',
                   country = 'USA')

contact <- new('contact',
               organizationName = 'Julie Ann Wrigley Global Institute of Sustainability, Arizona State University',
               positionName = 'Data Manager',
               address = giosAddress)

publisher <- new('publisher',
                 organizationName = 'Arizona State University, Julie Ann Wrigley Global Institute of Sustainability')

language <- 'english'

rights <- 'Copyright Board of Regents, Arizona State University. This information is released to the public and may be used for academic, educational, or commercial purposes subject to the following restrictions. While the CAP LTER will make every effort possible to control and document the quality of the data it publishes, the data are made available \'as is\'. The CAP LTER cannot assume responsibility for damages resulting from mis-use or mis-interpretation of datasets, or from errors or omissions that may exist in the data. It is considered a matter of professional ethics to acknowledge the work of other scientists that has resulted in data used in subsequent research. The CAP LTER expects that any use of data from this server will be accompanied with the appropriate citations and acknowledgments. The CAP LTER encourages users to contact the original investigator responsible for the data that they are accessing. Where appropriate, researchers whose projects are integrally dependent on CAP LTER data are encouraged to consider collaboration and/or co-authorship with original investigators. The CAP LTER requests that users submit to the Julie Ann Wrigley Global Institute of Sustainability at Arizona State University reference to any publication(s) resulting from the use of data obtained from this site. The CAP LTER requests that users not redistribute data obtained from this site. However, links or references to this site may be freely posted.'

# build order per REML
- dataset
- creator
- metadataProvider
- contact
- publisher
- title
- pubDate
- keywords
- abstract
- intellectualRights
- methods
- coverage
- dataTable
- physical
- attributeList
- additionalMetadata

# works but cannot incorporate custom_units
delta <- new('dataset',
#              scope = scope, # not sure the order of this one
#              system = system, # not sure the order of this one
             alternateIdentifier = alternateIdentifier,
             language = language,
             creator = creator,
             metadataProvider = metadataProvider,
             contact = contact,
             distribution = distribution,
             publisher = publisher,
             title = title,
             pubDate = pubDate,
             keywordSet = keys,
             abstract = abstract,
             intellectualRights = rights,
             # methods = methods,
             coverage = coverage,
             dataTable = c(runoffChemistry.DT,
                           rainfallChemistry.DT,
                           rainfall.DT,
                           discharge.DT,
                           particulates.DT,
                           samplingLocation.DT,
                           analyses.DT))

frank <- new('eml',
             dataset = delta)

eml_write(frank,
          file = "./outFile.xml")