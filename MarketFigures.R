source("sources.R")

metric_name <- "neb"

energy_burden_poverty_line <- 0.06
ner_poverty_line <- ner_func(g = 1,s = energy_burden_poverty_line)
metric_cutoff_level <- (ner_poverty_line)^-1

metric_long_name <- bquote(E[b]^n)
metric_label <- "%"

# as.expression(bquote(~italic(nE[b])~": Energy Burden"))


clean_data_ami_all <- read_csv("CohortData_AreaMedianIncome.csv")
clean_data_fpl_all <- read_csv("CohortData_FederalPovertyLine.csv")
replica_sup <- read_csv("CensusTractData.csv") #get_replica_supplemental_dataset()

census_tracts_shp <- get_tract_shapefiles(
  states="all",
  acs_version=2018,
  refresh=TRUE,
  return_files=TRUE,
  all_from_list=unique(replica_sup$state_abbr)
)


clean_data_ami_all$neb <- clean_data_ami_all$ner^-1
clean_data_fpl_all$neb <- clean_data_fpl_all$ner^-1

# clean_data_ami_all$neb <- ifelse(is.finite(clean_data_ami_all$neb),clean_data_ami_all$neb,max(clean_data_ami_all$neb, na.rm = T))
# clean_data_fpl_all$neb <- clean_data_fpl_all$ner^-1

clean_data_ami_all_sup <- left_join(clean_data_ami_all, replica_sup, by=c("geoid","state_abbr",
                                                                          "state_fips",
                                                                          "company_ty",
                                                                          "locale"))

clean_data_fpl_all_sup <- left_join(clean_data_fpl_all, replica_sup, by=c("geo_id"="geoid",
                                                                         "state_abbr",
                                                                         "state_fips"
))

clean_data_ami_all_sup_shp <- st_sf(left_join(census_tracts_shp, clean_data_ami_all_sup, by=c("gisjoin")))
clean_data_fpl_all_sup_shp <- st_sf(left_join(census_tracts_shp, clean_data_fpl_all_sup, by=c("gisjoin")))

rm(clean_data_ami_all, replica_sup, clean_data_ami_all_sup, census_tracts_shp)
rm(clean_data_fpl_all, replica_sup, clean_data_fpl_all_sup, census_tracts_shp)