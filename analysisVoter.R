#analysis example built at Open Data Day
#builds to logistic regression as way to analyze 
#descriptive power of available variables on early voting
##includes addition of variable that counts weeks between 
##registration date and date of election
###author :: ryan.tuggle@gmail.com

#load the data to frame
df <- read.csv('~/Repositories/data/votersDc_05MAR16.csv')
#convert Ward to factor
df['WARD'] <- as.factor(df$WARD)
#create voterId element
df['voterId'] <- row.names(df)
#extract the date of registration
df['dateRegister'] <- as.Date(sub("0:00", "", df$REGISTERED), "%m/%d/%y")
#create long data frame
library("tidyr")
##note: warning is ok -> some elections have different data types
dfl <- gather(df, electionId, outcome, X042815.S : X111994.G)
#extract election type variable
library("stringr")
dfl['typeElection'] <- str_sub(dfl$electionId, -1, -1)
#extract election time variable
dfl['dateElection'] <- as.Date(str_sub(dfl$electionId, 2, 7), "%m%d%y")
#find weeks registered at time of election
dfl['elapseRegister'] <- as.numeric(difftime(dfl$dateElection, dfl$dateRegister, units = "weeks"))
#create target variable -> 1 if early vote else 0
dfl['target'] <- as.numeric(dfl$outcome == "Y")
#subset the general election results since 2010, limit to only those who voted
dfs <- dfl[dfl$dateElection > 2010-01-01 
           & dfl$typeElection == 'G' 
           & dfl$outcome %in% c("Y", "V", "A")
           , ]
## group by ward to compare time correlations across wards
###note: add other dimensions to the group by to break out data in more detail
by_Ward <- group_by(dfs, WARD)
sumWard <- dplyr::summarize(by_Ward
                            , count = n()
                            , pct = mean(target)
                            , cor(elapseRegister, target, ))
#model the target variable with a logistic regression
fit <- glm(target ~ WARD+PARTY+elapseRegister, data = dfs, family=binomial())
summary(fit)
##compute significance with likelihood ratio compared with null model
fit.null <- glm(target ~ 1, data = dfs, family=binomial())
lrModel <- - (deviance(fit) / 2)
lrNull <- -(deviance(fit.null) / 2)
lr <- 2 * (lrModel - lrNull)
paste('likelihood ratio test statistic: ', lr)
paste('likelihood the model has no predictive power at all:'
      , (1 - pchisq(lr, 2)))


