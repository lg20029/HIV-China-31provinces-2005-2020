Spatiotemporal Dynamics and Policy Scenario Projections of HIV/AIDS in China: A 31-Province Analysis (2005–2030)
This repository contains the analysis code, processed datasets, and figures for the research paper "Spatiotemporal Dynamics and Policy Scenario Projections of HIV/AIDS in China: A 31-Province Analysis (2005–2030)".
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
├── code/                   # R analysis scripts
│   ├── 00_master_script.R  # Main control script (runs entire workflow)
│   ├── 01_joinpoint_analysis.R # Joinpoint analysis → Figure1, Figure4
│   ├── 02_apc_model.R      # APC model → Figure2, Figure5
│   ├── 03_bapc_prediction.R # BAPC prediction → Figure7, Figure8, Table1, Table2
│   └── 04_kmeans_clustering.R # K-means clustering → Figure3, Figure6
├── data/                   # Analytical datasets
│   ├── annual_cases_corrected.csv # Annual incidence data
│   ├── apc_data.csv        # APC model data
│   ├── apc_data_long.csv   # Long-format APC data
│   ├── cluster_data_updated.csv # Clustering analysis data
│   ├── cluster_result_updated.csv # Clustering results
│   ├── joinpoint_data.csv  # Input data for Joinpoint analysis
│   ├── provinces_summary_updated.csv # Provincial summary data
│   ├── scenario_analysis_corrected.csv # Scenario analysis results
│   └── Validation_Data_Summary_Complete.md # Documentation of validation data
├── figures/                # Paper figures
│   ├── Figure1_Annual_Trend.png
│   ├── Figure2_Age_Distribution.png
│   ├── Figure3_Provincial_Distribution.png
│   ├── Figure4_Joinpoint_Analysis.png
│   ├── Figure5_APC_Model.png
│   ├── Figure6_Clustering_Results.png
│   ├── Figure7_BAPC_Prediction.png
│   ├── Figure8_Scenario_Analysis.png
│   └── Figure9_Sensitivity_Analysis.png
├── README.md
└── LICENSE
Data Sources
Original Data (2005–2020): Obtained from the China Public Health Science Data Center (Link). Due to data use agreements, the raw dataset cannot be publicly shared.
Validation Data (2021–2023): Obtained from official publications of the National Administration of Disease Prevention and Control, China.
All processed datasets and R scripts necessary to reproduce the findings are available in this repository. A synthetic dataset mimicking the statistical properties of the original data is included in the data/ folder for code testing.
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
Joinpoint Regression: Identified the 2011 inflection point in national incidence trends (Figure1, Figure4).
Age-Period-Cohort (APC) Model: Decomposed age, period, and cohort effects using the Intrinsic Estimator (IE) method (Figure2, Figure5).
K-means Clustering: Classified 31 provinces into 5 clusters based on cumulative incidence, AAPC, and coefficient of variation (Figure3, Figure6).
Bayesian APC (BAPC): Projected incidence from 2021 to 2030 using INLA with Random Walk (RW1/RW2) priors (Figure7, Figure8, Table1, Table2).
Policy Scenarios: Projected incidence under "Constant Growth", "Moderate Acceleration", and "Intensified Intervention" scenarios (Figure8, Table2).
Sensitivity Analysis: Validated model robustness (Figure9).
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
