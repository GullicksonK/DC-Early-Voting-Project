
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
  summarize(prop_early=mean(ever_early), n=n()) %>%
  mutate(evn_dist_pos = as.numeric(str_match(evc_dist_bin, ",(\\d.\\d\\d)")[,2])) %>%
  filter(!is.na(evc_dist_bin))

ggplot(dist_v_early, 
       aes(evn_dist_pos, prop_early, size=n)) + 
  geom_segment(aes(xend=evn_dist_pos, yend=0, size=0)) +
  geom_point() +
  scale_x_continuous("Distance (Home to EV Location, miles)",
                     breaks=dist_v_early$evn_dist_pos,
                     labels=as.character(dist_v_early$evc_dist_bin)) +
  scale_y_continuous("Ever Voted Early", limits=c(0,.3), labels = scales::percent)  +
  scale_size_continuous("Voters") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))




