# Spatiotemporal Dynamics and Policy Scenarios of HIV/AIDS in China, 2005–2030

This repository contains the analysis code, processed datasets, and figures for the research paper "Spatiotemporal Dynamics and Policy Scenarios of HIV/AIDS in China, 2005–2030".

## Authors

- **Yu Shuang** (School of Economics and Management, Guangxi University of Science and Technology, Liuzhou, Guangxi, China)
- **Li Yiyao** (Wenhua Middle School, Liuzhou, Guangxi, China)
- **Li Guang** (Department of Public Health, School of Medicine, Guangxi University of Science and Technology, Liuzhou, Guangxi, China) - *Corresponding Author*

Corresponding author email: 6636749@qq.com

## Abstract

**Background:** The HIV/AIDS epidemic in China shows spatiotemporal heterogeneity, with an inflection point in 2011 (APC decreased from 23.6% to 6.8%). Implementing the China Action Plan (2024–2030) requires an understanding of these dynamics.

**Methods:** From 2005 to 2020, we examined surveillance data from 31 provinces. Age-period-cohort models decomposed age, period, and cohort effects; a five-cluster K-means algorithm classified provincial patterns; and Joinpoint regression identified trend break-points. Under three different policy scenarios, Bayesian APC models predicted incidence through 2030.

**Findings:** A total of 570,576 cases (171,240 deaths) were reported. Five clusters emerged, with Guangdong/Xinjiang showing moderate growth and Sichuan/Chongqing/Guizhou exhibiting rapid increases. The 50+ age group proportion rose from 11.2% (2005) to 49.3% (2020). BAPC projections indicate approximately 56,000 annual cases by 2030 (95% PI: 7,000–211,000). Achieving 95-95-95 targets could reduce incidence to ~17,000 cases annually.

## Repository Structure

```
hiv-aids-china-analysis/
├── README.md                           # This file
├── LICENSE                             # MIT License
├── code/                               # Analysis scripts
│   ├── 00_master_script.R              # Master script coordinating all analyses
│   ├── 01_joinpoint_analysis.R         # Joinpoint regression analysis (Figure 1)
│   ├── 02_kmeans_clustering.R          # K-means clustering analysis (Figure 2)
│   ├── 03_age_distribution.R           # Age distribution analysis (Figure 3)
│   ├── 04_apc_model.R                  # Age-Period-Cohort model (Figure 4)
│   ├── 05_bapc_prediction.R            # Bayesian APC prediction model (Figure 5)
│   └── 06_scenario_analysis.R          # Policy scenario analysis (Figure 6)
├── data/                               # Datasets
│   ├── HIV_AIDS_Data_31_Provinces.xlsx # Raw surveillance data (31 provinces, 2005-2020)
│   ├── joinpoint_data.csv              # Aggregated annual data for Joinpoint analysis
│   ├── cluster_result_updated.csv      # Provincial clustering results
│   ├── apc_data.csv                    # APC model input data
│   └── scenario_analysis_corrected.csv # Scenario projection results
└── figures/                            # Publication-ready figures
    ├── Figure1_Annual_Trend.png        # Annual trend with 2011 inflection point
    ├── Figure2_Clustering.png          # Provincial clustering map
    ├── Figure3_Age_Distribution.png    # Age distribution changes
    ├── Figure4_APC_Model.png           # APC model effects
    ├── Figure5_BAPC_Prediction.png     # BAPC prediction to 2030
    └── Figure6_Scenario_Analysis.png   # Policy scenario projections
```

## Data Description

### Raw Data
- **HIV_AIDS_Data_31_Provinces.xlsx**: National HIV/AIDS surveillance data from 31 provinces, autonomous regions, and municipalities in China (2005-2020). Data source: China Public Health Science Data Center.

### Processed Data
- **joinpoint_data.csv**: Annual cases, deaths, population, and incidence/mortality rates
- **cluster_result_updated.csv**: Provincial clustering results with cumulative cases, incidence rates, and AAPC
- **apc_data.csv**: Age-period-cohort structured data for APC modeling
- **scenario_analysis_corrected.csv**: Projected cases under three policy scenarios (2020-2030)

## Analysis Scripts

### Script Overview

| Script | Purpose | Output |
|--------|---------|--------|
| `00_master_script.R` | Coordinates execution of all scripts | All figures |
| `01_joinpoint_analysis.R` | Joinpoint regression for trend analysis | Figure 1 |
| `02_kmeans_clustering.R` | K-means clustering of provincial patterns | Figure 2 |
| `03_age_distribution.R` | Age distribution analysis | Figure 3 |
| `04_apc_model.R` | Age-Period-Cohort model (Intrinsic Estimator) | Figure 4 |
| `05_bapc_prediction.R` | Bayesian APC prediction (R-INLA) | Figure 5 |
| `06_scenario_analysis.R` | Policy scenario projections | Figure 6 |

### Dependencies

**R version:** 4.3.0 or higher

**Required R packages:**
- tidyverse
- readxl
- ggplot2
- patchwork
- cluster
- factoextra
- apc
- INLA (for BAPC)

**Installation:**
```r
# Install CRAN packages
install.packages(c("tidyverse", "readxl", "ggplot2", "patchwork", 
                   "cluster", "factoextra", "apc"))

# Install INLA
install.packages("INLA", repos = c(getOption("repos"), 
                  INLA = "https://inla.r-inla-download.org/R/stable"))
```

### Running the Analysis

```r
# Set working directory to the code folder
setwd("path/to/code")

# Run individual scripts
source("01_joinpoint_analysis.R")
source("02_kmeans_clustering.R")
source("03_age_distribution.R")
source("04_apc_model.R")
source("05_bapc_prediction.R")
source("06_scenario_analysis.R")

# Or run all scripts via master script
source("00_master_script.R")
```

## Key Findings

1. **Trend Analysis**: Annual HIV/AIDS cases increased from 5,621 (2005) to 62,167 (2020), with an inflection point in 2011 where APC decreased from 23.6% to 6.8%.

2. **Provincial Clustering**: Five distinct clusters identified:
   - Cluster 1 (High-prevalence rapid-growth): Sichuan, Chongqing, Guizhou
   - Cluster 2 (High-prevalence stable): Guangxi, Yunnan
   - Cluster 3 (Special stable): Henan
   - Cluster 4 (Moderate-prevalence moderate-growth): 9 provinces
   - Cluster 5 (Low-prevalence rapid-growth): 17 provinces

3. **Age Shift**: Proportion of cases among people aged 50+ increased from 11.2% (2005) to 49.3% (2020).

4. **Projections**: 
   - BAPC baseline: ~56,000 cases/year by 2030
   - Constant growth scenario: ~120,640 cases by 2030
   - Intensified intervention (95-95-95): ~17,300 cases by 2030

## Policy Implications

1. **Targeted Interventions**: High-prevalence rapid-growth provinces require intensified prevention efforts
2. **Aging Population**: Projected 55–60% of cases among those aged 50+ by 2030
3. **Emerging Hotspots**: 17 low-prevalence rapid-growth provinces require proactive surveillance

## Citation

If you use this code or data, please cite the paper:

Yu Shuang, Li Yiyao, Li Guang. Spatiotemporal Dynamics and Policy Scenarios of HIV/AIDS in China, 2005–2030. [Journal Name], 202X.

### BibTeX
```bibtex
@article{yu2025hiv,
  title={Spatiotemporal Dynamics and Policy Scenarios of HIV/AIDS in China, 2005--2030},
  author={Yu, Shuang and Li, Yiyao and Li, Guang},
  journal={[Journal Name]},
  year={202X}
}
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

For any questions regarding the code or data, please contact:

**Li Guang** (Corresponding Author)  
Department of Public Health, School of Medicine  
Guangxi University of Science and Technology  
Email: 6636749@qq.com

## Acknowledgements

We thank the China Public Health Science Data Center for data support and the National Center for AIDS/STD Control and Prevention, China CDC for technical guidance.

## Funding

This work was supported by the Doctoral Research Foundation of Guangxi University of Science and Technology. The funder had no role in study design, data collection, analysis, or manuscript preparation.

## Data Availability

All data and code necessary to reproduce the analyses in this paper are available in this repository. The raw surveillance data (`HIV_AIDS_Data_31_Provinces.xlsx`) is provided with permission from the China Public Health Science Data Center.

