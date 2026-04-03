Spatiotemporal Dynamics and Policy Scenarios of HIV/AIDS in China, 2005–2030
This repository contains the analysis code, processed datasets, and figures for the research paper "Spatiotemporal Dynamics and Policy Scenarios of HIV/AIDS in China, 2005–2030".
Authors
•Yu Shuang (School of Economics and Management, Guangxi University of Science and Technology, Liuzhou, Guangxi, China)
•Li Yiyao (Wenhua Middle School, Liuzhou, Guangxi, China)
•Li Guang (Department of Public Health, School of Medicine, Guangxi University of Science and Technology, Liuzhou, Guangxi, China) - Corresponding Author
Corresponding author email: 6636749@qq.com
Abstract
Background
The HIV/AIDS epidemic in China shows spatiotemporal heterogeneity, with an inflection point in 2011 (APC decreased from 23.6% to 6.8%). Implementing the China Action Plan (2024–2030) requires an understanding of these dynamics.
Methods
From 2005 to 2020, we examined surveillance data from 31 provinces. Age-period-cohort models decomposed age, period, and cohort effects; a five-cluster K-means algorithm classified provincial patterns; and Joinpoint regression identified trend break-points. Under three different policy scenarios, Bayesian APC models predicted incidence through 2030.
Findings
A total of 570,576 cases (171,240 deaths) were reported. Five clusters emerged, with Guangdong/Xinjiang categorized as medium-prevalence despite high cumulative counts and Henan exhibiting unique stabilization (AAPC 3.68%). Under baseline trends, BAPC predicted about 54,500 cases per year by 2030; increased intervention (95-95-95 targets) could lower this to about 17,000 per year.
Conclusions
Current epidemic momentum rather than historical cumulative burden should guide prevention priorities. By 2030, accelerating targets could bring infection rates down to less than 0.2%.
Key Findings
1.2011 Inflection Point: A significant inflection point was identified in 2011, with annual percent change (APC) decreasing from 23.6% (95% CI: 18.5–28.9) during 2005–2011 to 6.8% (95% CI: 3.2–10.6) during 2012–2020.
2.Five Provincial Epidemic Patterns: K-means clustering identified five distinct provincial epidemic patterns:
•High-prevalence rapid-growth type (Sichuan, Chongqing, Guizhou): mean cumulative incidence 90.07 per 100,000, mean AAPC 39.8%
•High-prevalence stable type (Yunnan, Guangxi): highest cumulative incidence (mean 147.32 per 100,000), controlled growth (mean AAPC 14.76%)
•Special stable type (Henan): unique epidemiological characteristics with AAPC of only 3.68%
•Medium-prevalence medium-growth type (8 provinces including Beijing, Shanghai, Guangdong, Xinjiang)
•Low-prevalence rapid-growth type (17 provinces): mean AAPC 28.92%, representing emerging epidemic hotspots
3.Aging Epidemic: 35.6% of all cases from 2005 to 2020 were among people aged 50 and older, substantially higher than the global figure of 21.4%. By 2030, the proportion of cases among people aged 50 and older is projected to increase to 55–60%.
4.Policy Scenario Projections: Under the intensified intervention scenario (meeting 95-95-95 targets), annual incidence could drop to approximately 17,000 cases by 2030, compared to approximately 54,500 under baseline trends and approximately 120,640 under constant growth scenario.
Repository Structure
├── code/
│   ├── 00_master_script.R       # Main control script
│   ├── 01_joinpoint_analysis.R  # Joinpoint analysis → Figure 1
│   ├── 02_apc_model.R           # APC model → Figure 4
│   ├── 03_bapc_prediction.R     # BAPC prediction → Figure 5, 6, Table 1
│   └── 04_kmeans_clustering.R   # K-means clustering → Figure 2
├── data/
│   ├── annual_cases_corrected.csv
│   ├── apc_data.csv
│   ├── cluster_data_updated.csv
│   └── ...
├── figures/
│   ├── Figure1_Annual_Trend.png
│   ├── Figure2_Clustering_Results.png
│   └── ...
├── README.md
└── LICENSE
Data Sources
•Original Data (2005–2020): Obtained from the China Public Health Science Data Center. Due to data use agreements, the raw dataset cannot be publicly shared.
•Validation Data (2021–2023): Obtained from official publications of the National Administration of Disease Prevention and Control, China.
Software and Packages
R Packages
Package	Version	Purpose
apc	2.0.0	Age-Period-Cohort analysis using Intrinsic Estimator
INLA	-	Bayesian APC projections (Integrated Nested Laplace Approximation)
stats/cluster	-	K-means clustering analysis
ggplot2	-	Data visualization
Joinpoint Regression
Joinpoint regression analysis was conducted using the Joinpoint Desktop Software (version 4.9.0.0). You can download it from the National Cancer Institute Website.
Methodology Overview
1. Joinpoint Regression
Identified the 2011 inflection point in national incidence trends using log-linear Poisson models with Monte-Carlo permutation tests. Calculated annual percent change (APC) and average annual percent change (AAPC).
Formula: APC = (exp(β) − 1) × 100
2. Age-Period-Cohort (APC) Model
Decomposed age, period, and cohort effects using the Intrinsic Estimator (IE) method. The model takes the form:
log(λ(apc)) = μ + αa + βp + γc
where αa represents the age effect, βp the period effect, and γc the cohort effect.
3. K-means Clustering
Classified 31 provinces into 5 clusters based on:
•Cumulative incidence per 100,000 population
•Average annual percent change (AAPC)
•Coefficient of variation (CV) in annual case counts
4. Bayesian APC (BAPC)
Projected incidence from 2021 to 2030 using INLA with:
•First-order random walk (RW1) priors for cohort effects
•Second-order random walk (RW2) priors for age and period effects
•Weakly informative priors: Gamma(1, 0.00005)
Validation Performance: Internal validation MAPE: 7.71%; External validation: 100% prediction-interval coverage for 2021–2023.
5. Policy Scenarios
Projected incidence under three scenarios:
•Constant-Growth Scenario: Assuming 2012–2020 APC (6.84%) remains constant
•Moderate-Acceleration Scenario: 85% diagnosis rate by 2025, 90–95% by 2030
•Intensified-Intervention Scenario: 90-95-95 targets by 2025, 95-95-95 by 2030
Policy Implications
This study provides actionable evidence for implementing the China Action Plan for Containment and Prevention of AIDS (2024–2030):
1.Diagnosis Gap: Current 84.3% diagnosis rate requires 5.7 percentage points increase to meet 2025 target
2.Aging Population: Projected 55–60% of cases among those aged 50+ by 2030
3.Emerging Hotspots: 17 low-prevalence rapid-growth provinces require proactive surveillance
Citation
If you use this code or data, please cite the paper:
Yu Shuang, Li Yiyao, Li Guang. Spatiotemporal Dynamics and Policy Scenarios of HIV/AIDS in China, 2005–2030. [Journal Name], 202X.
BibTeX
@article{yu2025hiv,
  title={Spatiotemporal Dynamics and Policy Scenarios of HIV/AIDS in China, 2005--2030},
  author={Yu, Shuang and Li, Yiyao and Li, Guang},
  journal={[Journal Name]},
  year={202X}
}
License
This project is licensed under the MIT License - see the LICENSE file for details.
Contact
For any questions regarding the code or data, please contact:
Li Guang (Corresponding Author)
Department of Public Health, School of Medicine
Guangxi University of Science and Technology
Email: 6636749@qq.com
Acknowledgements
We thank the China Public Health Science Data Center for data support and the National Center for AIDS/STD Control and Prevention, China CDC for technical guidance.
Funding
This work was supported by the Doctoral Research Foundation of Guangxi University of Science and Technology. The funder had no role in study design, data collection, analysis, or manuscript preparation.
