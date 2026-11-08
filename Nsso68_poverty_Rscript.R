# =====================================================================
# NSS 68th Round (2011-12): Poverty and inequality analysis
# Data: Household Consumer Expenditure, Schedule 1.0 Type 1 (MoSPI)
# Poverty lines: Tendulkar Committee, 2011-12 (state x sector)
# =====================================================================


# 1. SETUP ----
# Install packages ONCE in the console (not in this script), because
# installing on every run is slow and needs internet:
# install.packages(c("haven", "dplyr", "tidyr", "readxl", "ggplot2"))

library(haven)    # read_xpt(): reads the SAS-format (.xpt) NSS files
library(dplyr)    # select, mutate, group_by, joins
library(tidyr)    # pivot_wider (used for the rural-urban gap)
library(readxl)   # read_excel (poverty lines)
library(ggplot2)  # plots

# Two addresses are written once, here, so only these two lines change
# if the project moves to another computer.
project_dir <- "~/NSSO Poverty Analysis"
raw_dir     <- "~Downloads/Data_in_CSV/Data_in_CSV"

# Work from the project folder, so "Data/..." and "Output/..." paths work.
setwd(project_dir)


# 2. LOAD DATA ----
# Only Levels 1, 2 and 3 are needed:
#   Level 1 = identification, state, sector, multiplier
#   Level 2 = household size, social group
#   Level 3 = MPCE (already summarised from the item-level files)
# Levels 4-7 hold item-level spending; rebuilding MPCE from them would
# give the same figure, so they are skipped.
f <- list.files(raw_dir, full.names = TRUE)

l1 <- read_xpt(f[grepl("Level 1", f, fixed = TRUE)])
l2 <- read_xpt(f[grepl("Level 2", f, fixed = TRUE)])
l3 <- read_xpt(f[grepl("Level 3", f, fixed = TRUE)])


# 3. MERGE LEVELS 1, 2 AND 3 ----
# No single column identifies a household, so a household is identified
# by four codes taken together (like a full address).
ids <- c("FSU_Serial_no", "Hamlet_Group_Sub_Stratum_No",
         "Second_Stage_Stratum_No", "Sample_hhld_no")

# Keep only the needed columns from each file. Many columns share a name
# across files (Sector, State_code, MLT...), and merging everything would
# create confusing duplicates like Sector.x and Sector.y.
d1 <- l1 %>% select(all_of(ids), Sector, State_code, MLT, NSS, NSC)
d2 <- l2 %>% select(all_of(ids), HH_Size, Social_Group)
d3 <- l3 %>% select(all_of(ids), MPCE_MRP)

hh <- d1 %>% inner_join(d2, by = ids) %>% inner_join(d3, by = ids)


# 4. CHECKS (optional: run when needed) ----
# Each level has one row per household, so the merged data should keep
# all 101,662 rows and have zero duplicated households.
dim(l1); dim(l2); dim(l3)
dim(hh)
sum(duplicated(hh[ids]))

# Inspect the columns and the first rows of each file:
# names(l1); names(l2); names(l3)
# head(l1, 3); head(l2, 3); head(l3, 3)

# How many households follow each weight rule (see section 5)?
table(hh$NSS == hh$NSC)


# 5. WEIGHTS AND MPCE ----
# The survey visited about 100,000 households, and each one represents
# many others. The multiplier (MLT) says how many, so results need weights.
# The sample was collected in two sub-samples, so, following the NSS
# guidelines, weight = MLT/100 if NSS == NSC, otherwise MLT/200.

# HH_Size is stored as text, so it is converted to a number first.
# Person weight = household weight x household size, because poverty
# counts people, and a bigger household stands for more people.
hh <- hh %>%
  mutate(
    HH_Size = as.numeric(HH_Size),
    wt = ifelse(NSS == NSC, MLT/100, MLT/200),
    pw = wt * HH_Size
  )

# MPCE is stored in paise (two implied decimals), so divide by 100 to
# get rupees per person per month.
hh <- hh %>% mutate(MPCE = MPCE_MRP / 100)

# Quick checks: no missing household size, no zero or negative values.
summary(hh$MPCE)
summary(hh$pw)
sum(is.na(hh$HH_Size))

# Sector is coded 1 = rural, 2 = urban.
table(hh$Sector)
hh <- hh %>% mutate(sector = ifelse(Sector == "1", "Rural", "Urban"))

# Plausibility check on the average MPCE (persons as the unit).
hh %>% group_by(sector) %>% summarise(avg_MPCE = weighted.mean(MPCE, pw))


# 6. POVERTY LINES ----
# Each household is compared with the Tendulkar line for its OWN state and
# sector, because prices differ across states and between rural and urban.
# The Excel file is read once; the header sits in row 2, so skip = 1.
# The "All India" rows have no state number and are dropped.
pl_raw <- read_excel("Data/Tendulkar Povertyline.xlsx", skip = 1) %>%
  filter(!is.na(state))

pl        <- pl_raw %>% select(state, sector = sctr, line = `2011-12`)
names_tbl <- pl_raw %>% distinct(state, state_name = statenm)

# State codes in the NSS data are text ("01"), but numbers in the Excel
# file, so convert them or the join silently fails.
hh <- hh %>% mutate(state = as.numeric(State_code))
hh <- hh %>% left_join(pl, by = c("state", "sector"))

# Must be 0: every household found a poverty line.
sum(is.na(hh$line))


# 7. HEADCOUNT POVERTY RATIO ----
# A household (and every person in it) is poor if MPCE is below its line.
# The weighted mean of a 0/1 variable is the share of 1s, so weighting by
# person weight gives the percentage of PERSONS who are poor.
hh <- hh %>% mutate(poor = ifelse(MPCE < line, 1, 0))

hh %>% group_by(sector) %>%
  summarise(HCR = 100 * weighted.mean(poor, pw))

100 * weighted.mean(hh$poor, hh$pw)

# Validation: this gave about 25.4 rural, 13.7 urban, 22.0 overall, against
# official figures of about 25.7, 13.7 and 21.9 (within about 0.3 points).
# State results for Kerala and Chhattisgarh also matched the published ones.


# 8. ROBUSTNESS: WEIGHT RULE ----
# Same ratio using MLT/100 for everyone. A weight factor applies equally to
# the numerator and the denominator, so it largely cancels in a ratio.
# Compare these with section 7 and note the difference here:
hh <- hh %>% mutate(pw_alt = (MLT/100) * HH_Size)

hh %>% group_by(sector) %>%
  summarise(HCR_alt = 100 * weighted.mean(poor, pw_alt))


# 9. STATE-WISE POVERTY ----
state_pov <- hh %>%
  group_by(state, sector) %>%
  summarise(HCR = 100 * weighted.mean(poor, pw), .groups = "drop") %>%
  left_join(names_tbl, by = "state")      # add state names for labels

print(state_pov, n = 80)

write.csv(state_pov, "Output/state_poverty_estimates.csv", row.names = FALSE)


# 10. PLOTS: STATES ----
# reorder() sorts bars by value; coord_flip() lays them sideways so the
# long state names can be read.
rural <- state_pov %>% filter(sector == "Rural")

ggplot(rural, aes(x = reorder(state_name, HCR), y = HCR)) +
  geom_col() + coord_flip() +
  labs(x = NULL, y = "Rural poverty (%)",
       title = "Rural poverty by state, 2011-12")
ggsave("Output/Plots/rural_poverty_states.png", width = 8, height = 9)

urban <- state_pov %>% filter(sector == "Urban")

ggplot(urban, aes(x = reorder(state_name, HCR), y = HCR)) +
  geom_col() + coord_flip() +
  labs(x = NULL, y = "Urban poverty (%)",
       title = "Urban poverty by state, 2011-12")
ggsave("Output/Plots/urban_poverty_states.png", width = 8, height = 9)

# Rural-urban gap: pivot_wider puts rural and urban side by side per
# state, which makes the subtraction easy.
gap <- state_pov %>%
  select(state_name, sector, HCR) %>%
  pivot_wider(names_from = sector, values_from = HCR) %>%
  mutate(gap = Rural - Urban)

ggplot(gap, aes(x = reorder(state_name, gap), y = gap)) +
  geom_col() + coord_flip() +
  labs(x = NULL, y = "Rural minus urban poverty (percentage points)",
       title = "Rural-urban poverty gap by state, 2011-12")
ggsave("Output/Plots/rural_urban_gap.png", width = 8, height = 9)

# Both sectors side by side (quick comparison; crowded with 35 states).
ggplot(state_pov, aes(x = reorder(state_name, HCR), y = HCR, fill = sector)) +
  geom_col(position = "dodge") + coord_flip() +
  labs(x = NULL, y = "Poverty (%)", fill = "Sector",
       title = "Poverty by state and sector, 2011-12")
ggsave("Output/Plots/poverty_state_sector.png", width = 8, height = 11)


# 11. POVERTY BY SOCIAL GROUP ----
table(hh$Social_Group)

# Codes: 1 = ST, 2 = SC, 3 = OBC, 9 = Others.
# Checked against the data layout file.
# 14 households have no recorded social group; they become NA and are
# excluded below, since they are too few to matter.
hh <- hh %>% mutate(
  caste = case_when(
    Social_Group == "1" ~ "ST",
    Social_Group == "2" ~ "SC",
    Social_Group == "3" ~ "OBC",
    Social_Group == "9" ~ "Others"
  )
)

# n = number of sampled households, to show how much data sits behind
# each ratio.
pov_caste <- hh %>%
  filter(!is.na(caste)) %>%
  group_by(sector, caste) %>%
  summarise(HCR = 100 * weighted.mean(poor, pw), n = n(), .groups = "drop")

pov_caste

# All-India ratio by group (both sectors together).
hh %>% filter(!is.na(caste)) %>%
  group_by(caste) %>%
  summarise(HCR = 100 * weighted.mean(poor, pw))

ggplot(pov_caste, aes(x = caste, y = HCR, fill = sector)) +
  geom_col(position = "dodge") +
  labs(x = NULL, y = "Poverty (%)", fill = "Sector",
       title = "Poverty by social group, 2011-12")
ggsave("Output/Plots/poverty_by_social_group.png", width = 7, height = 5)


# 12. INEQUALITY: GINI AND LORENZ CURVE ----
# Unit = persons, weighted by person weight (as for poverty).
# The standard Gini() function ignores weights, so it is written out here.
gini_w <- function(x, w) {
  o <- order(x); x <- x[o]; w <- w[o]        # sort people poorest to richest
  p <- cumsum(w) / sum(w)                    # cumulative share of people
  L <- cumsum(w * x) / sum(w * x)            # cumulative share of spending
  p0 <- c(0, p[-length(p)]); L0 <- c(0, L[-length(L)])
  1 - sum((p - p0) * (L + L0))               # 1 minus area under Lorenz curve
}

# Gini by sector. The all-India figure is higher than rural because it also
# reflects the gap BETWEEN rural and urban spending levels, not only the
# inequality within each sector.
hh %>% group_by(sector) %>%
  summarise(Gini = gini_w(MPCE, pw))

gini_w(hh$MPCE, hh$pw)

# Lorenz curves: group_by() makes the sorting and cumulative sums happen
# separately for each sector. The curve that bows further below the dashed
# equality line is the more unequal one.
lor_both <- hh %>%
  group_by(sector) %>%
  arrange(MPCE, .by_group = TRUE) %>%
  mutate(p = cumsum(pw) / sum(pw),
         L = cumsum(pw * MPCE) / sum(pw * MPCE)) %>%
  ungroup()

ggplot(lor_both, aes(p, L, colour = sector)) + geom_line() +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  labs(x = "Cumulative share of persons", y = "Cumulative share of spending",
       colour = "Sector", title = "Lorenz curves, 2011-12")
ggsave("Output/Plots/lorenz_curves.png", width = 7, height = 5)
