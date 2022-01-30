# knb-lter-cap.624: CAP LTER stormwater

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
