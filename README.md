Spatiotemporal Dynamics and Policy Scenario Projections of HIV/AIDS in China: A 31-Province Analysis (2005–2030)
This repository contains the data and analysis code for the research paper "Spatiotemporal Dynamics and Policy Scenario Projections of HIV/AIDS in China: A 31-Province Analysis (2005–2030)".
Authors
Yu Shuang (School of Economics and Management, Guangxi University of Science and Technology)
Li Yiyao (Wenhua Middle School)
Li Guang (Department of Public Health, School of Medicine, Guangxi University of Science and Technology) - *Corresponding Author*
Abstract
This study analyzes the spatiotemporal dynamics of HIV/AIDS in 31 Chinese provinces from 2005 to 2020 and projects trends through 2030 under various policy scenarios. We utilized Joinpoint regression, Age-Period-Cohort (APC) models, K-means clustering, and Bayesian APC (BAPC) models.
Key Findings:
A significant inflection point was identified in 2011, with APC decreasing from 23.6% to 6.8%.
Five distinct provincial epidemic patterns were identified.
Under the intensified intervention scenario (meeting 95-95-95 targets), annual incidence could drop to ~17,000 cases by 2030, compared to ~54,500 under baseline trends.
Repository Structure
The repository is organized as follows:
├── data/                   # Datasets used in the study
│   ├── raw_data.csv        # Raw surveillance data (complete-case analysis)
│   └── validation_data.csv # Validation data (2021-2023)
├── scripts/                # R scripts and code
│   ├── 01_data_cleaning.R  # Data processing and missing value handling
│   ├── 02_joinpoint_analysis.R # Preparation for Joinpoint software
│   ├── 03_APC_Model.R      # Age-Period-Cohort analysis using Intrinsic Estimator
│   ├── 04_Kmeans_Clustering.R # Provincial clustering analysis
│   ├── 05_BAPC_Projection.R # Bayesian APC projection using INLA
│   └── 06_Policy_Scenarios.R # Deterministic scenario calculations
├── results/                # Output figures and tables
├── README.md
└── LICENSE
Data Sources
Surveillance Data (2005–2020): Obtained from the China Public Health Science Data Center (Link).
Validation Data (2021–2023): Obtained from official publications of the National Administration of Disease Prevention and Control, China.
Software and Packages
The analysis was performed using R and Joinpoint Software.
R Packages
The following R packages are required to run the scripts:
apc (version 2.0.0): For Age-Period-Cohort analysis using the Intrinsic Estimator.
INLA: For Bayesian Age-Period-Cohort projections (Integrated Nested Laplace Approximation).
stats / cluster: For K-means clustering analysis.
ggplot2: For data visualization.
Joinpoint Regression
Joinpoint regression analysis was conducted using the Joinpoint Desktop Software (version 4.9.0.0). You can download it from the National Cancer Institute Website.
Methodology Overview
Joinpoint Regression: Identified the 2011 inflection point in national incidence trends.
Age-Period-Cohort (APC) Model: Decomposed age, period, and cohort effects using the Intrinsic Estimator (IE) method.
K-means Clustering: Classified 31 provinces into 5 clusters based on cumulative incidence, AAPC, and coefficient of variation.
Bayesian APC (BAPC): Projected incidence from 2021 to 2030 using INLA with Random Walk (RW1/RW2) priors.
Policy Scenarios: Projected incidence under "Constant Growth", "Moderate Acceleration", and "Intensified Intervention" scenarios.
Citation
If you use this code or data, please cite the paper:
Yu Shuang, Li Yiyao, Li Guang. Spatiotemporal Dynamics and Policy Scenario Projections of HIV/AIDS in China: A 31-Province Analysis (2005–2030). *[Insert Journal Name]*, 202X.
BibTeX:
@article{yu2025hiv,
  title={Spatiotemporal Dynamics and Policy Scenario Projections of HIV/AIDS in China: A 31-Province Analysis (2005–2030)},
  author={Yu, Shuang and Li, Yiyao and Li, Guang},
  journal={[Journal Name]},
  year={202X}
}
License
This project is licensed under the MIT License - see the LICENSE file for details.
Contact
For any questions regarding the code or data, please contact Li Guang (Corresponding Author).
