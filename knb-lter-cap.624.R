
# README ----

# reml slots ----
getSlots("dataset")
  getSlots("distribution")
  getSlots("keywordSet")
    getSlots("keyword")
getSlots("dataTable")
getSlots("physical")
  getSlots("dataFormat")
    getSlots("textFormat")
  getSlots("size")
  getSlots("distribution")
    getSlots("online")
      getSlots("url")
getSlots("additionalInfo")
  getSlots("section")
  getSlots("para")
getSlots("metadataProvider")
  getSlots("individualName")
  getSlots("userId")
getSlots("creator")
  getSlots("individualName")
  getSlots("userId")

# libraries ----
library(EML)
library(RPostgreSQL)
library(RMySQL)
library(tidyverse)
library(tools)
library(readxl)
library(aws.s3)
library(capeml)

# reml-helper-functions ----
source('~/localRepos/reml-helper-tools/writeAttributesFn.R')
source('~/localRepos/reml-helper-tools/createDataTableFromFileFn.R')
source('~/localRepos/reml-helper-tools/createKMLFn.R')
source('~/localRepos/reml-helper-tools/address_publisher_contact_language_rights.R')
source('~/localRepos/reml-helper-tools/createOtherEntityFn.R')
source('~/localRepos/reml-helper-tools/createPeople.R')
source('~/localRepos/reml-helper-tools/createFactorsDataframe.R')

# connections ----

# Amazon
source('~/Documents/localSettings/aws.s3')
  
# postgres
source('~/Documents/localSettings/pg_prod.R')
source('~/Documents/localSettings/pg_local.R')
  
pg <- pg_prod
pg <- pg_local

# mysql
source('~/Documents/localSettings/mysql_prod.R')
prod <- mysql_prod

# dataset details to set first ----
projectid <- 624
packageIdent <- 'knb-lter-cap.624.2'
pubDate <- '2018-02-28'


# runoff chemistry --------------------------------------------------------

# data from 2007 (single storm at IBW) omitted owing to lack of times 61 values
# sans an analysis id are omitted
runoffChemistry <- dbGetQuery(pg, "
  SELECT
    s.bottle,
    sites.abbreviation AS runoff_location,
    s.sample_datetime AS runoff_datetime,
    r.replicate,
    a.analysis_name AS analysis,
    r.concentration,
    dq.data_qualifier_label AS data_qualifier,
    r.comments
FROM
  stormwater.results r
  JOIN stormwater.samples s ON (s.sample_id = r.sample_id)
  JOIN stormwater.analysis a ON (r.analysis_id = a.analysis_id)
  JOIN stormwater.sites ON (s.site_id = sites.site_id)
  LEFT JOIN stormwater.data_qualifier dq ON (dq.data_qualifier_id = r.data_qualifier)
WHERE
  EXTRACT (YEAR FROM s.sample_datetime) > 2007 AND
  r.analysis_id IS NOT NULL AND
  (bottle NOT ILIKE '%rain%' OR bottle IS NULL);")

# need to add a definitive reference for whether a sample is a blank given that
# bottle is omitted (and confusing)
runoff_chemistry <- runoffChemistry %>%
  mutate(
    blank = as.factor(ifelse(grepl('blk|blank', bottle, ignore.case = T), 'TRUE', 'FALSE')),
    runoff_location = as.factor(runoff_location),
    analysis = as.factor(analysis)
  ) %>%
  select(-bottle)

# writeAttributes(runoff_chemistry) # write data frame attributes to a csv in current dir to edit metadata

runoff_chemistry_desc <- "stormwater runoff chemistry during runoff-generating storms at CAP LTER stormwater sampling sites"

# runoff_chemistry_factors <- factorsToFrame(runoff_chemistry)

# create data table based on metadata provided in the companion csv
# use createdataTableFn() if attributes and classes are to be passed directly
runoff_chemistry_DT <- createDTFF(dfname = runoff_chemistry,
                                  # factors = runoff_chemistry_factors,
                                  description = runoff_chemistry_desc,
                                  dateRangeField = 'runoff_datetime')


# rainfall chemistry ------------------------------------------------------

rainfallChemistry <- dbGetQuery(pg, "
SELECT
  sites.abbreviation AS rain_location,
  s.sample_datetime AS rain_datetime,
  r.replicate,
  a.analysis_name AS analysis,
  r.concentration,
  dq.data_qualifier_label AS data_qualifier,
  r.comments
FROM
  stormwater.results r
  JOIN stormwater.samples s ON (s.sample_id = r.sample_id)
  JOIN stormwater.analysis a ON (r.analysis_id = a.analysis_id)
  JOIN stormwater.sites ON (s.site_id = sites.site_id)
  LEFT JOIN stormwater.data_qualifier dq ON (dq.data_qualifier_id = r.data_qualifier)
WHERE
  EXTRACT (YEAR FROM s.sample_datetime) > 2007 AND
  r.analysis_id IS NOT NULL AND
  bottle ILIKE '%rain%'
ORDER BY sites.abbreviation, s.sample_datetime, a.analysis_name;")

rainfall_chemistry <- rainfallChemistry %>%
  mutate(
    rain_location = as.factor(rain_location),
    analysis = as.factor(analysis),
    rain_datetime = format(rain_datetime, format = "%Y-%m-%d")
  )

# writeAttributes(rainfall_chemistry) # write data frame attributes to a csv in current dir to edit metadata

rainfall_chemistry_desc <- "water chemistry of collected rainfall at CAP LTER stormwater sampling sites"

# rainfall_chemistry_factors <- factorsToFrame(rainfall_chemistry)

# create data table based on metadata provided in the companion csv
# use createdataTableFn() if attributes and classes are to be passed directly
rainfall_chemistry_DT <- createDTFF(dfname = rainfall_chemistry,
                                    # factors = rainfall_chemistry_factors,
                                    description = rainfall_chemistry_desc,
                                    dateRangeField = 'rain_datetime')



# rainfall ----------------------------------------------------------------

rainfall <- dbGetQuery(pg,"
SELECT
  sites.abbreviation AS rain_location,
  r.event_datetime AS rain_datetime,
  r.rainfall_quantity AS rain_quantity
FROM
  stormwater.rainfall r
  JOIN stormwater.sites ON (r.site_id = sites.site_id);")

rainfall <- rainfall %>%
  mutate(
    rain_location = as.factor(rain_location)
  )

# writeAttributes(rainfall) # write data frame attributes to a csv in current dir to edit metadata

rainfall_desc <- "depth of precipitation as measured by tipping bucket rain gauge at CAP LTER stormwater sampling sites"

# rainfall_factors <- factorsToFrame(rainfall)

# create data table based on metadata provided in the companion csv
# use createdataTableFn() if attributes and classes are to be passed directly
rainfall_DT <- createDTFF(dfname = rainfall,
                          # factors = rainfall_factors,
                          description = rainfall_desc,
                          dateRangeField = 'rain_datetime')


# discharge ---------------------------------------------------------------

discharge <- dbGetQuery(pg, "
SELECT
  sites.abbreviation AS discharge_location,
  r.event_datetime AS discharge_datetime,
  r.water_height AS water_height,
  r.discharge AS raw_discharge,
  r.discharge_corrected AS edited_discharge
FROM
  stormwater.discharge r
  JOIN stormwater.sites ON (r.site_id = sites.site_id)
;")

discharge <- discharge %>%
  mutate(
    discharge_location = as.factor(discharge_location)
  )

# writeAttributes(discharge) # write data frame attributes to a csv in current dir to edit metadata

discharge_desc <- "discharge at CAP LTER stormwater sampling sites"

# discharge_factors <- factorsToFrame(discharge)

# create data table based on metadata provided in the companion csv
# use createdataTableFn() if attributes and classes are to be passed directly
discharge_DT <- createDTFF(dfname = discharge,
                           # factors = discharge_factors,
                           description = discharge_desc,
                           dateRangeField = 'discharge_datetime')


# particulates ------------------------------------------------------------

particulates <- dbGetQuery(pg, "
SELECT
  s.bottle,
  sites.abbreviation AS runoff_location,
  s.sample_datetime AS runoff_datetime,
  r.replicate AS replicate,
  r.filter_initial AS filter_wt,
  r.filter_dry AS filter_dry_wt,
  r.volume_filtered AS vol_filtered,
  r.filter_ashed AS filter_ash_wt,
  r.data_qualifier AS data_qualifier,
  r.comments AS comments
FROM
  stormwater.solids r
  JOIN stormwater.samples s ON (s.sample_id = r.sample_id)
  JOIN stormwater.sites ON (s.site_id = sites.site_id)
  LEFT JOIN stormwater.data_qualifier dq ON (dq.data_qualifier_id = r.data_qualifier);")

particulates <- particulates %>%
  mutate(
    blank = as.factor(ifelse(grepl('blk|blank', bottle, ignore.case = T), 'TRUE', 'FALSE')),
    runoff_location = as.factor(runoff_location),
    data_qualifier = as.character(data_qualifier)
  ) %>%
  select(-bottle)

# writeAttributes(particulates) # write data frame attributes to a csv in current dir to edit metadata

particulates_desc <- "mass of particulates in stormwater during runoff-generating storms at CAP LTER stormwater sampling sites"

# particulates_factors <- factorsToFrame(particulates)

# create data table based on metadata provided in the companion csv
# use createdataTableFn() if attributes and classes are to be passed directly
particulates_DT <- createDTFF(dfname = particulates,
                              # factors = particulates_factors,
                              description = particulates_desc,
                              dateRangeField = 'runoff_datetime')



# sample location ---------------------------------------------------------

# NEED LAT LONGS for Price and Salt R. sites!

sampling_location <- dbGetQuery(pg,"
SELECT
  abbreviation AS runoff_location,
  site_name AS name,
  latitude,
  longitude
FROM stormwater.sites;")

sampling_location <- sampling_location %>%
  mutate(
    runoff_location = as.factor(runoff_location)
  )

# writeAttributes(sampling_location) # write data frame attributes to a csv in current dir to edit metadata

sampling_location_desc <- "catalog of CAP LTER stormwater sampling locations"

# sampling_location_factors <- factorsToFrame(sampling_location)

# create data table based on metadata provided in the companion csv
# use createdataTableFn() if attributes and classes are to be passed directly
sampling_location_DT <- createDTFF(dfname = sampling_location,
                                   # factors = sampling_location_factors,
                                   description = sampling_location_desc)



# analyses ----------------------------------------------------------------

analytes <- dbGetQuery(pg,"
SELECT
  DISTINCT ON (analysis_name)
  analysis_name as analysis,
  analysis_description AS description,
  units,
  instrument
FROM
  stormwater.analysis
  RIGHT JOIN stormwater.results r ON (r.analysis_id = analysis.analysis_id)
WHERE analysis_name IS NOT NULL;")


# writeAttributes(analytes) # write data frame attributes to a csv in current dir to edit metadata

analytes_desc <- "catalog and details of water chemistry analytes measured as part of CAP LTER stormwater monitoring"

# analytes_factors <- factorsToFrame(analytes)

# create data table based on metadata provided in the companion csv
# use createdataTableFn() if attributes and classes are to be passed directly
analytes_DT <- createDTFF(dfname = analytes,
                          # factors = analyses_factors,
                          description = analytes_desc)



# catchments --------------------------------------------------------------

stormwater_catchments <- createKML(kmlobject = 'stormwater_catchments.kml',
                                   description = "The location and configuration of watersheds that are or have been sampled as part of the CAP LTER's research on stormwater monitoring in the greater Phoenix metropolitan area. Catchments for sampling locations along the Salt River (centralNorth, centralSouth, Ave7th) and Price have not been delineated by the CAP LTER.")


# data entity ----

# data processing
# data_frame_name[data_frame_name == ''] <- NA

# see comments in createdataTableFn.R for doing this piece-by-piece outside of functions

writeAttributes(dataframe) # write data frame attributes to a csv in current dir to edit metadata
dataframe_desc <- "dataframe description"

# address factors if needed
reach <- c(Tonto = "Salt River, Tonto National Forest, near Usery Road",
           BM = "Baseline and Meridian Wildlife Area")
urbanized <- c(urban = "in urban area",
               NonUrban = "outside urban area")
restored <- c(Restored = "site received active restoration",
              NotRestored = "site has not been restored")

dataframe_factors <- factorsToFrame(dataframe)

# create data table based on metadata provided in the companion csv
# use createdataTableFn() if attributes and classes are to be passed directly
dataframe_DT <- createDTFF(dfname = dataframe,
                           # factors = dataframe_factors,
                           description = dataframe_desc
                           # dateRangeField = 'date field'
                           )


# title and abstract ----
title <- 'title of data set'

# abstract from file or directly as text
abstract <- as(set_TextType("abstract_as_md_file.md"), "abstract") 
abstract <- 'abstract text'


# people ----

# creators
nancyGrimm <- addCreator('n', 'grimm')
danChilders <- addCreator('d', 'childers')

creators <- c(as(nancyGrimm, 'creator'),
              as(danChilders, 'creator'))

# metadata providers
stevanEarl <- addMetadataProvider('s', 'earl')

metadataProvider <-c(as(stevanEarl, 'metadataProvider'))

# associated parties
stanFaeth <- addAssocParty('s', 'faeth', 'Former Associate of Study')
markHostetler <- addAssocParty('m', 'hostetler', 'Former Associate of Study')

associatedParty <- c(as(stanFaeth, 'associatedParty'),
                     as(markHostetler, 'associatedParty'))

# project personnel
yujiaZhang <- addPersonnel('yuj', 'zhang', 'data creator and provider')
xiaoxiaoLi <- addPersonnel('xiaox', 'li', 'data creator and provider')

projectPersonnel <-c(as(yujiaZhang, 'personnel'),
                     as(xiaoxiaoLi, 'personnel'))


# keywords ----

# CAP IRTs for reference: https://sustainability.asu.edu/caplter/research/
# be sure to include these as appropriate

keywordSet <-
  c(new("keywordSet",
        keywordThesaurus = "LTER controlled vocabulary",
        keyword =  c("urban",
                     "dissolved organic carbon",
                     "total dissolved nitrogen")),
    new("keywordSet",
        keywordThesaurus = "LTER core areas",
        keyword =  c("disturbance patterns",
                     "movement of inorganic matter")),
    new("keywordSet",
        keywordThesaurus = "Creator Defined Keyword Set",
        keyword =  c("unlisted stuff",
                     "unlisted stuff")),
    new("keywordSet",
        keywordThesaurus = "CAPLTER Keyword Set List",
        keyword =  c("cap lter",
                     "cap",
                     "caplter",
                     "central arizona phoenix long term ecological research",
                     "arizona",
                     "az",
                     "arid land"))
    )

# methods and coverages ----
methods <- set_methods("methods_as_md_file.md")

# if relevant, pulling dates from a DB is nice
# begindate <- dbGetQuery(con, "SELECT MIN(sample_date) AS date FROM database.table;")
# begindate <- begindate$date

begindate <- "2005-11-05"
enddate <- "2015-12-15"
geographicDescription <- "CAP LTER study area"
coverage <- set_coverage(begin = begindate,
                         end = enddate,
                         sci_names = c("Salix spp",
                                       "Ambrosia deltoidea"),
                         geographicDescription = geographicDescription,
                         west = -111.949, east = -111.910,
                         north = +33.437, south = +33.430)

# project ----

projectDetails <- new("project",
                      title = "project title",
                      personnel = projectPersonnel,
                      funding = "This project was supported by...")

# construct the dataset ----

# from sourced file:
  # address
  # publisher
  # contact
  # rights
  # distribution

# DATASET
dataset <- new("dataset",
               title = title,
               creator = creators,
               pubDate = pubDate,
               metadataProvider = metadataProvider,
               # associatedParty = associatedParty,
               intellectualRights = rights,
               abstract = abstract,
               keywordSet = keywordSet,
               coverage = coverage,
               contact = contact,
               methods = methods,
               distribution = metadata_dist,
               dataTable = c(first_DT,
                             second_DT))
               # otherEntity = c(core_arthropod_locations)) # if other entity is relevant

# ls(pattern= "_DT") # can help to pull out DTs

# assembly line flow that would be good to incorporate - build the list of DTs at creation
# data_tables_stored <- list()
# data_tables_stored[[i]] <- data_table
# dataset@dataTable <- new("ListOfdataTable",
#                      data_tables_stored)

# construct the eml ----

# CUSTOM UNITS
# standardUnits <- get_unitList()
# unique(standardUnits$unitTypes$id) # unique unit types

custom_units <- rbind(
  data.frame(id = "microsiemenPerCentimeter",
             unitType = "conductance",
             parentSI = "siemen",
             multiplierToSI = 0.000001,
             description = "electric conductance of lake water in the units of microsiemenPerCentimeter"),
data.frame(id = "nephelometricTurbidityUnit",
           unitType = "unknown",
           parentSI = "unknown",
           multiplierToSI = 1,
           description = "(NTU) ratio of the amount of light transmitted straight through a water sample with the amount scattered at an angle of 90 degrees to one side"))
unitList <- set_unitList(custom_units)

# note schemaLocation is new, not yet tried!
eml <- new("eml",
           schemaLocation = "eml://ecoinformatics.org/eml-2.1.1  http://nis.lternet.edu/schemas/EML/eml-2.1.1/eml.xsd",
           packageId = packageIdent,
           scope = "system",
           system = "knb",
           access = lter_access,
           dataset = dataset,
           additionalMetadata = as(unitList, "additionalMetadata"))


# assembly line code to incorporate next round!

# if (custom_units == "yes"){
#   eml <- new("eml",
#              schemaLocation = "eml://ecoinformatics.org/eml-2.1.1  http://nis.lternet.edu/schemas/EML/eml-2.1.1/eml.xsd",
#              packageId = data_package_id,
#              system = root_system,
#              access = access,
#              dataset = dataset,
#              additionalMetadata = as(unitsList, "additionalMetadata"))
# } else {
#   eml <- new("eml",
#              schemaLocation = "eml://ecoinformatics.org/eml-2.1.1  http://nis.lternet.edu/schemas/EML/eml-2.1.1/eml.xsd",
#              packageId = data_package_id,
#              system = root_system,
#              access = access,
#              dataset = dataset)
# }
# 
# # Write EML
# 
# print("Writing EML ...")
# 
# write_eml(eml, paste(path, "/", data_package_id, ".xml", sep = ""))
# 
# # Validate EML
# 
# print("Validating EML ...")
# 
# validation_result <- eml_validate(eml)
# 
# if (validation_result == "TRUE"){
#   
#   print("EML passed validation!")
#   
# } else {
#   
#   print("EML validaton failed. See warnings for details.")
#   
# }

# write the xml to file ----
write_eml(eml, "out.xml")


# S3 functions ----

# misc commands
 
  # get list of buckets
  # bucketlist()
  # 
  # add an object to S3 - datasets
  # put_object(file = '649_maintenance_log_dd68e293482738ac6f05303d473687a2.csv',
  #            object = '/datasets/cap/649_maintenance_log_dd68e293482738ac6f05303d473687a2.csv',
  #            bucket = 'gios-data')
  # 
  # add an object to S3 - metadata
  # put_object(file = '~/Dropbox/development/knb-lter-cap.650.1/knb-lter-cap.650.1.xml',
  #            object = '/metadata/knb-lter-cap.650.1.xml',
  #            bucket = 'gios-data')
  # 
  # get files in the gios-data bucket with the prefix datasets/cap/650
  # get_bucket(bucket = 'gios-data',
  #            prefix = 'datasets/cap/650')

# data file to S3
dataToAmz <- function(fileToUpload) {
  
  put_object(file = fileToUpload,
             object = paste0('/datasets/cap/', basename(fileToUpload)),
             bucket = 'gios-data') 
  
}

# example
# dataToAmz('~/Dropbox/development/knb-lter-cap.650.1/CAP 30m Landsat Series Submit/650_CAP_1985_0c95b18e82df5eb0302a46e5967bb1e1.zip')


# metadata file to S3
emlToAmz <- function(fileToUpload) {
  
  put_object(file = fileToUpload,
             object = paste0('/metadata/', basename(fileToUpload)),
             bucket = 'gios-data') 
  
}

# example
# emlToAmz('~/localRepos/cap-data/cap-data-eml/knb-lter-cap.650.1.xml')