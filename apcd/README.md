# [All Payer Claims Database](http://www.vhi.org/APCD/) (APCD)

Useful material for the pulling supplemental data for and performing analysis
on APCD datasets. 

## Load American Community Survey (ACS) data
Uses the python censusdata API to programmatically extract and aggregate 
census variables defined in a [config file](data/acs_variables.csv).

## Load ZCTA-level GIS data
Downloads a dataset containing GIS geometries for Us ZCTAs.

## Load ZIP-tract crosswalk
Combines ZIP-tract crosswalk files from multiple years with slightly different
formats into a single standardized file.
