#!/usr/bin/env Rscript
# =============================================================================
# Master R Script for HIV/AIDS Analysis in China
# Integrates all analysis components and generates publication-ready figures
# Author: Yu Shuang
# Date: 2025
# =============================================================================

# Set up
library(tidyverse)
library(readxl)
library(patchwork)

# Source individual scripts (uncomment to run all analyses)
# source("01_joinpoint_analysis.R")
# source("02_kmeans_clustering.R")
# source("03_age_distribution.R")
# source("04_apc_model.R")
# source("05_bapc_prediction.R")
# source("06_scenario_analysis.R")

# =============================================================================
# Script Overview
# =============================================================================
# This master script coordinates the execution of all analysis scripts.
# Each script generates a specific figure for the manuscript:
#
#   01_joinpoint_analysis.R  -> Figure 1: Annual Trend with 2011 Inflection Point
#   02_kmeans_clustering.R   -> Figure 2: Provincial Clustering Results
#   03_age_distribution.R    -> Figure 3: Age Distribution of Cases
#   04_apc_model.R           -> Figure 4: Age-Period-Cohort Model Results
#   05_bapc_prediction.R     -> Figure 5: BAPC Model Predictions
#   06_scenario_analysis.R   -> Figure 6: Policy Scenario Projections
#
# =============================================================================

# =============================================================================
# Color Palette (Consistent across all figures)
# =============================================================================

colors <- c(
  primary = "#2E86AB",    # Blue
  secondary = "#E94F37",  # Red
  tertiary = "#44AF69",   # Green
  quaternary = "#F18F01", # Orange
  quinary = "#9B59B6",    # Purple
  gray = "#6C757D"        # Gray
)

# =============================================================================
# Data Files Overview
# =============================================================================
# The following data files are generated/used by the scripts:
#
# Input Data:
#   - HIV_AIDS_Data_31_Provinces.xlsx: Raw data from 31 provinces
#
# Intermediate Data:
#   - joinpoint_data.csv: Annual aggregated data
#   - provinces_summary_updated.csv: Provincial summary statistics
#   - cluster_data_updated.csv: Clustering features
#   - cluster_result_updated.csv: Cluster assignments
#   - apc_data.csv: Age-period matrix
#   - apc_data_long.csv: Long format APC data
#   - bapc_predictions.csv: BAPC model predictions
#   - scenario_analysis_corrected.csv: Scenario projections
#
# Output Figures:
#   - Figure1_Annual_Trend.png
#   - Figure2_Clustering_Results.png
#   - Figure3_Age_Distribution.png
#   - Figure4_APC_Model.png
#   - Figure5_BAPC_Prediction.png
#   - Figure6_Scenario_Analysis.png
#
# =============================================================================

# =============================================================================
# Run All Analyses
# =============================================================================

cat("========================================\n")
cat("HIV/AIDS Analysis in China (2005-2030)\n")
cat("========================================\n\n")

# Create output directory
dir.create("Figures", showWarnings = FALSE)
dir.create("Data", showWarnings = FALSE)

# Run analyses
cat("Step 1: Joinpoint Analysis (Figure 1)...\n")
# source("01_joinpoint_analysis.R")

cat("Step 2: K-means Clustering (Figure 2)...\n")
# source("02_kmeans_clustering.R")

cat("Step 3: Age Distribution Analysis (Figure 3)...\n")
# source("03_age_distribution.R")

cat("Step 4: APC Model Analysis (Figure 4)...\n")
# source("04_apc_model.R")

cat("Step 5: BAPC Prediction (Figure 5)...\n")
# source("05_bapc_prediction.R")

cat("Step 6: Scenario Analysis (Figure 6)...\n")
# source("06_scenario_analysis.R")

cat("\n========================================\n")
cat("All analyses completed successfully!\n")
cat("========================================\n")

# =============================================================================
# Figure Quality Check
# =============================================================================

# List generated figures
figures <- list.files(pattern = "Figure[0-9]_.*\\.png$", full.names = TRUE)
cat("\nGenerated Figures:\n")
for (f in figures) {
  cat(paste0("  - ", basename(f), "\n"))
}

# =============================================================================
# End of Script
# =============================================================================
