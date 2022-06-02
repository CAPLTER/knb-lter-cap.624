# knb-lter-cap.624: CAP LTER stormwater

### knb-lter-cap.624.5 *2022-06-02*

#### version 5 reflects a major update to this data package:

* workflow updated to _revised_ capeml config.yaml style
- data refresh
- addresses a mistake with Lachat phosphorus data where data after 2019 were reported at ug/L whereas all data prior are reported as mg/L; in light of this error CAP will finally drop the conversion of phosphate as it comes off the Lachat in units of ug/L to mg/L and, instead, report all Lachat-derived phosphate values as ug/L
- this update peels off data specific to the SNAZ project
  - rainfall chem and amount data are removed completely as those measurements were exclusive to SNAZ
  - runoff chemistry, particulates, discharge, sampling locations, and watershed polygons pared to non-SNAZ sites
  - SNAZ data are reported in knb-lter-cap.702
  - provenance to knb-lter-cap.702 included here (and, conversely, knb-lter-cap.624 referenced in knb-lter-cap.702)
- runoff data lacking a datetime value are removed


### knb-lter-cap.624.4 *2022-01-29*

- data refresh
- convert attributes and factors to yaml style


### knb-lter-cap.624.3

* workflow updated to capeml featuring config.yaml
* pH included with runoff_chemistry; temperature not included owing to the
  inherent meaningless of that measurement in this context; salinity and TDS
  (meter) not included owing to very scant values for those measurements; pH
  not recorded on rain samples
* improved location description
* locations from table to kml


### knb-lter-cap.624.2

This version 624.2 is a new workflow based on the Rmd format. There are new
data available but, in the interest of time for the review, only data currently
in the database at the time of construction are going into this version 2. More
recent data and the discharge project stuff at the Salt River sites need to go
into a version 3 soon.

Note that this new workflow if pretty-much hit the button and everything should
be built. Still not addressed at in this current configuration, however, are
the keyword attributes, so those still have to be done by hand. Note also that
the kml file is going to be overwritten every time.
