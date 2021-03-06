#######################################################
###                                                 ###
#     "Early Interventions in Online Education"       #
#    Discovery of Heterogeneous Treatment Effects     #
#                   02/01/2017                        #
###                                                 ###
#######################################################

#setwd("~/git/Joint-Interventions-At-Scale/")
require(sparsereg)
require(dplyr)

# Loading simulated dataset
load("simdat.rda")

#######################################################
### Sample Selection and Data Transformation        ###
#######################################################
#
# Selecting baseline sample just as in prereg.R analyses
data = ungroup(data %>% 
    filter(webservice_call_complete == 1 & !is.na(affirm) & !is.na(plans)) %>%
    group_by(id) %>% 
    arrange(survey_timestamp) %>% 
    mutate(
      first.exposure = row_number() == 1,
      num.exposures = n(),
      days.to.next.exposure = ifelse(num.exposures > 1, diff(survey_timestamp)[1] / (60*60*24), 0),
      clean.exposure = first.exposure & (num.exposures == 1 | days.to.next.exposure > 29)
    ))

analysis_timestamp = 1487145600 # e.g. 2/15/2017
data = mutate(data,
   survey.delay = (survey_timestamp - first_activity_timestamp) / (60*60), # b.
   days.from.start = (first_activity_timestamp - course_start_timestamp) / (60*60*24), # c1.
   days.to.analysis = (analysis_timestamp - first_activity_timestamp) / (60*60*24), # c2.
   itt.sample = clean.exposure & # a.
     (survey.delay < 1) & # b.
     ((course_selfpaced & (days.to.analysis > 29)) | ((!course_selfpaced) & (days.from.start < 15))) # c1|c2
)

data = data %>% filter(itt.sample)

# Transforming variables for sparse model
data = data %>% mutate(
  age = 2017 - yob,
  educ_phd = educ == 9,
  educ_ma_prof = educ %in% (7:8),
  educ_ba = educ == 6,
  educ_some_he = educ %in% (4:5),
  more_educ_than_parents = educ > educ_parents,
  is_teacher = teach == 1,
  is_employed = empstatus == 1,
  is_unemployed = empstatus == 2,
  is_ft_student = empstatus == 3,
  is_pt_student = school == 1 & school_ftpt == 0,
  is_blended = school == 1 & school_online > 2,
  is_hs_student = school == 1 & school_lev %in% (1:3),
  is_college_student = school == 1 & school_lev %in% (4:6),
  born_in_US = pob == 187
)

covariates = c("intent_lecture", "intent_assess", "hours", "crs_finish",
               "goal_setting", "fam", "educ_parents", "age", "gender_female", "gender_other",
               "educ_phd", "educ_ma_prof", "educ_ba", "educ_some_he", "more_educ_than_parents",
               "is_teacher", "is_employed", "is_unemployed", "is_ft_student", "is_pt_student",
               "is_college_student","is_hs_student","is_blended", "fluent", "threat_country", 
               "olei_olei_interest", "olei_olei_job", "olei_olei_degree", "olei_olei_research", 
               "olei_olei_growth", "olei_olei_career", "olei_olei_fun", "olei_olei_social",
               "olei_olei_experience", "olei_olei_certificate", "olei_olei_uniprof", 
               "olei_olei_peer", "olei_olei_language", "HDI4", "born_in_US")

treatments = c("affirm", "plans_short", "plans_long")

#######################################################
### Fitting Sparsereg Model and Evaluating Results  ###
#######################################################

# Fitting linear probability instead of probit model for 
# binary outcome for increased interpretability
SPR = sparsereg(
    y = data$cert_basic, 
    X = data.matrix(data[, covariates]), 
    treat = data[, treatments],
    id = data$course,
    id2 = data$strata,
    type = "linear",
    EM = F,
    scale.type = "TX",
    conservative = F
  )

summary(SPR)
plot(SPR)
violinplot(SPR)

#######################################################
