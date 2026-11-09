# Poverty and Inequality in India, 2011-12 (NSS 68th Round)

Independent practice project: estimating poverty and inequality in India from household microdata, written in R.

Author:MARYAM JILANI

## Objective

To estimate the share of persons living below the poverty line in rural and urban India, by state and by social group, and to measure how unequally household spending is distributed. Poverty is measured with the official Tendulkar poverty lines, and the results are checked against published official estimates.

## Data

- **Survey:** NSS 68th Round (July 2011 to June 2012), Household Consumer Expenditure, Schedule 1.0 Type 1, from MoSPI (Ministry of Statistics and Programme Implementation).
- **Poverty lines:** Tendulkar Committee lines for 2011-12, by state and sector (`Data/Tendulkar Povertyline.xlsx`).
- The raw survey files are licensed and are not included in this repository. They can be downloaded from the MoSPI microdata portal (mospi.gov.in).

The survey has 11 record levels. This analysis uses Levels 1, 2, and 3:

| Level | Content |
|---|---|
| Level 1 | household identifiers, state, sector, sampling multiplier |
| Level 2 | household size, social group |
| Level 3 | monthly per capita consumption expenditure (MPCE) |

The item-level files (Levels 4 to 7) are not needed, because Level 3 already holds the final MPCE built from them.

## Method

1. **Merge** Levels 1, 2 and 3 on four household codes (FSU, hamlet-group/sub-block, second-stage stratum, household number). No single column identifies a household. The merged file keeps all 101,662 households with no duplicates.
2. **Weights.** Each sampled household stands for many others, so the sampling multiplier is used. Weight = multiplier/100 if the NSS and NSC sub-sample codes are equal, otherwise multiplier/200.Person weight = household weight x household size, because poverty is counted over persons.
3. **MPCE.** The stored value is in paise, so it is divided by 100 to give rupees per person per month.
4. **Poverty line.** Each household is compared with the Tendulkar line for its own state and sector. A household is poor if its MPCE is below that line.
5. **Headcount ratio.** The person-weighted share of persons who are poor.
6. **Social group.** Households are grouped as ST, SC, OBC and Others. The 14 households with no recorded social group are excluded from this part.
7. **Inequality.** A person-weighted Gini coefficient and Lorenz curves of MPCE, for rural and urban areas.

## Validation

All-India headcount ratios are close to the official 2011-12 estimates (about 25.7% rural, 13.7% urban, 21.9% overall):

| | My project | Official (approx.) |
|---|---|---|
| Rural | 25.4% | 25.7% |
| Urban | 13.7% | 13.7% |
| All India | 22.0% | 21.9% |

Results are consistent with official Planning Commission estimates for 2011–12. Chhattisgarh (44.6%), and Kerala (9.2%) all match published figures closely.

Using multiplier/100 for every household instead of the two-rule weight gives [rural 25.4%, urban 13.7%], so the weight rule does not change the conclusions.

## Key results

- **Rural poverty is higher than urban poverty** nationally (25.4% against 13.7%).DNH records the highest rural poverty (62.6%), driven by extreme intra-UT inequality between its industrial belt and tribal rural settlements — structurally different from high-poverty states like Chhattisgarh or Jharkhand.Bihar has one of the smallest rural–urban gaps (3.2 pp) but high absolute poverty in both sectors, pointing to generalised deprivation rather than a sectoral divide.Southern and coastal states (Kerala 9.2%, Goa 6.8%) record the lowest rural poverty.North-eastern states show elevated rural poverty despite low population density, reflecting geographical isolation and weak market integration.
- **Social groups:** poverty is highest among ST households and lowest among Others, in both sectors. In rural areas the ratios are about 45.3% (ST), 31.5% (SC), 22.7% (OBC) and 15.5% (Others).
- **Inequality:** the Gini coefficient is 0.287 in rural areas and 0.377 in urban areas (0.359 for all India). Spending is more unevenly spread in urban India.

These are associations from one survey year and do not show causes.

## Outputs

In the `Output/` folder:

- `state_poverty_estimates.csv`:  poverty ratios for all 35 states/UTs by sector
- `rural_poverty_states.png`, `urban_poverty_states.png`: states ranked by poverty
- `rural_urban_gap.png`: rural minus urban poverty by state
- `poverty_state_sector.png`: rural and urban poverty by state, side by side
- `poverty_by_social_group.png`: poverty by social group and sector
- `lorenz_curves.png`: Lorenz curves for rural and urban India

## Project structure

```
NSSO Poverty Analysis/
├── README.md
├── nsso68_poverty.R
├── Data/
│   └── Tendulkar Povertyline.xlsx
└── Output/
```

## How to run

1. Download the NSS 68th round Schedule 1.0 Type 1 data from MoSPI.
2. In `nsso68_poverty.R`, set `project_dir` (this folder) and `raw_dir` (where the survey files are).
3. Install the packages once: `install.packages(c("haven", "dplyr", "tidyr", "readxl", "ggplot2"))`.
4. Run the whole script.

## Tools

R with `haven`, `dplyr`, `tidyr`, `readxl` and `ggplot2`.

## Limitations

- Estimates use the Tendulkar lines for 2011-12 and one survey year, so they say nothing about trends.
- Small states and union territories have few sampled households, so their ratios are less reliable.
- Differences from the official figures of a few tenths of a percentage point can arise from rounding and weighting details.

## Sources

- National Sample Survey Office, Household Consumer Expenditure Survey, NSS 68th Round (July 2011 to June 2012), MoSPI, Government of India.
- Planning Commission, Government of India, Tendulkar Committee poverty lines and poverty estimates for 2011-12.
