
options(stringsAsFactors = FALSE)

library(dplyr)
library(RSQLite)
library(lubridate)
library(stringr)
library(readr)
library(magrittr)
library(tidyr)
library(ggplot2)
library(scales)

load("EarlyVoting.Rdata")

# plot distance vs probability of ever voting early
addr_dist <- select(address, FULLADDRESS, EVC_DIST) %>%
  group_by(FULLADDRESS) %>% 
  summarise(MIN_EVC_DIST=min(EVC_DIST))

voter_addr <- vote %>%
  group_by(voter_id) %>%
  summarize(ever_early=any(action=="Early", na.rm=TRUE)) %>%
  ungroup() %>%
  inner_join(select(voter, voter_id, FULLADDRESS)) %>%
  inner_join(addr_dist)

voter_addr %<>%
  mutate(evc_dist_bin = Hmisc::cut2(MIN_EVC_DIST, c(0, .25, .5, .75, 1, 1.5, 2, 3)))

dist_v_early <- voter_addr %>%
  group_by(evc_dist_bin) %>%
  summarize(prop_early=mean(ever_early), n=n())

ggplot(filter(dist_v_early, !is.na(evc_dist_bin)), 
       aes(evc_dist_bin, prop_early, size=n)) + 
  geom_segment(aes(xend=evc_dist_bin, yend=0, size=0)) +
  geom_point() +
  xlab("Distance (Home to EV Location, miles)") +
  scale_y_continuous("Ever Voted Early", limits=c(0,.3)) 



