# this script loads and normalizes the data file into SQLite

options(stringsAsFactors = FALSE)

library(dplyr)
library(RSQLite)
library(lubridate)
library(stringr)
library(readr)
library(magrittr)
library(tidyr)

data_name <- "Full Voter Roll.csv"
dat <- read_csv(data_name)
addr_file <- "Master Address Repository-Address Points.csv"

norm_addr <- function(x) {
  str_replace_all(x, 
                  c(" ST "=" STREET ", " AVE "=" AVENUE ",
                    " PL "=" PLACE ", " RD "=" ROAD ",
                    " TER "=" TERRACE ", " HWY "=" HIGHWAY ",
                    " DR "=" DRIVE ", " CT "=" COURT ",
                    " CIR "=" CIRCLE ", " LN "=" LANE ",
                    " BLVD "=" BOULEVARD ", " CRES "=" CRESCENT ",
                    " PKY "=" PARKWAY "))
}

dat %<>%
  rename(RES_STREET=`RES STREET`) %>%
  mutate(voter_id = seq_len(nrow(dat)))

voter <- dat %>%
  select(voter_id, REGISTERED, STATUS, PARTY, RES_HOUSE, RES_STREET) %>%
  mutate(FULLADDRESS=norm_addr(paste(RES_HOUSE, RES_STREET))) %>%
  select(-RES_HOUSE, -RES_STREET) %>%
  distinct() %>%
  mutate(REGISTERED=mdy_hm(REGISTERED))

address <- dat %>%
  select(RES_HOUSE, RES_APT, RES_STREET, RES_CITY, RES_ZIP, PRECINCT, WARD, ANC, SMD) %>%
  distinct()
address %<>% 
  mutate(FULLADDRESS = norm_addr(paste(RES_HOUSE, RES_STREET)))

actions <- data.frame(action_cd=c("A", "E", "N", "V", "Y"),
                      action=c("Absentee", "Did not vote", "Not eligible",
                               "Voted", "Early"))

vote <- dat %>%
  select(voter_id, contains("-")) %>%
  gather(election, action_cd, -voter_id) %>%
  left_join(actions) %>%
  select(-action_cd)

election_types <- data.frame(type_cd=c("S", "G", "P"),
                             type=c("Special", "General", "Primary"))

election <- vote %>%
  select(election) %>%
  distinct() %>%
  extract(election, into=c("date_str", "type_cd"),
          regex="([[:alnum:]]+)-([[:alnum:]])",
          remove=FALSE) %>%
  left_join(election_types) %>%
  select(-type_cd) %>%
  mutate(election_day=mdy(date_str),
         presidential = (year(election_day) %% 4 == 0) & (month(election_day) == 11))


addr_dat <- read_tsv(addr_file)

addr_dat %<>% select(FULLADDRESS, RES_LAT, RES_LONG, EVC_LAT, EVC_LONG, EVC_DIST) %>%
  distinct()


# fuzzy match addresses

address %<>% left_join(addr_dat)

save(vote, election, voter, address, file="EarlyVoting.Rdata")


  

  


  

