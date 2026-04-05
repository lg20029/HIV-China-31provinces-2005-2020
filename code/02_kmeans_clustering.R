#!/usr/bin/env Rscript
# =============================================================================
# R Script for K-means Clustering of Provincial HIV/AIDS Epidemic Patterns
# Generates Figure 2: Clustering Results
# Author: Yu Shuang
# Date: 2025
# =============================================================================

# Install and load required packages
if (!require("tidyverse")) install.packages("tidyverse", repos = "https://cloud.r-project.org/")
if (!require("cluster")) install.packages("cluster", repos = "https://cloud.r-project.org/")
if (!require("factoextra")) install.packages("factoextra", repos = "https://cloud.r-project.org/")
if (!require("readxl")) install.packages("readxl", repos = "https://cloud.r-project.org/")

library(tidyverse)
library(cluster)
library(factoextra)
library(readxl)

# =============================================================================
# 1. Data Preparation
# =============================================================================

# Read the raw data
raw_data <- read_excel("HIV_AIDS_Data_31_Provinces.xlsx")

# Coerce columns to correct types
raw_data <- raw_data %>%
  mutate(
    Cases          = suppressWarnings(as.numeric(Cases)),
    Incidence_Rate = suppressWarnings(as.numeric(Incidence_Rate)),
    Mortality_Rate = suppressWarnings(as.numeric(Mortality_Rate)),
    Deaths         = suppressWarnings(as.numeric(Deaths)),
    year_num       = as.integer(substr(Date, 1, 4))
  )

# 2020 Census Population (millions) for 31 provinces
# Source: China Seventh National Population Census (2020)
province_pop <- tribble(
  ~Province,          ~pop_million,
  "Anhui",            61.03,
  "Beijing",          21.89,
  "Chongqing",        32.05,
  "Fujian",           41.55,
  "Gansu",            25.02,
  "Guangdong",        126.01,
  "Guangxi",          50.13,
  "Guizhou",          38.56,
  "Hainan",           10.08,
  "Hebei",            74.61,
  "Heilongjiang",     31.85,
  "Henan",            99.37,
  "Hubei",            57.75,
  "Hunan",            66.44,
  "Inner Mongolia",   24.05,
  "Jiangsu",          84.72,
  "Jiangxi",          45.19,
  "Jilin",            24.07,
  "Liaoning",         42.59,
  "Ningxia",          7.20,
  "Qinghai",          5.92,
  "Shaanxi",          39.53,
  "Shandong",         101.53,
  "Shanghai",         24.87,
  "Shanxi",           34.92,
  "Sichuan",          83.67,
  "Tianjin",          13.87,
  "Tibet",            3.65,
  "Xinjiang",         25.85,
  "Yunnan",           47.21,
  "Zhejiang",         64.57
)

# Aggregate to province-year level (sum over age groups and months)
province_year <- raw_data %>%
  group_by(Province, year_num) %>%
  summarise(
    annual_cases = sum(Cases, na.rm = TRUE),
    .groups = "drop"
  )

# =============================================================================
# 2. Feature Engineering for Clustering
# =============================================================================

# Calculate the three features described in Online Methods:
# (1) Cumulative incidence per 100,000 population
#     = total_cases (2005-2020) / population * 100,000
# (2) AAPC (Average Annual Percent Change) over 2005-2020
#     = log-linear regression of annual case counts
# (3) CV (Coefficient of Variation) in annual case counts
#     = SD(annual_cases) / Mean(annual_cases)

provincial_summary <- province_year %>%
  left_join(province_pop, by = "Province") %>%
  group_by(Province) %>%
  summarise(
    total_cases    = sum(annual_cases, na.rm = TRUE),
    pop_million    = first(pop_million),
    cum_incidence  = total_cases / (pop_million * 1e6) * 1e5,
    aapc = {
      sub <- cur_data()
      years <- sub$year_num
      cases <- sub$annual_cases
      if (nrow(sub) >= 2) {
        log_cases <- log(pmax(cases, 0.5))
        X <- years - years[1]
        slope <- coef(lm(log_cases ~ X))[2]
        round((exp(slope) - 1) * 100, 2)
      } else NA_real_
    },
    cv = {
      sub <- cur_data()
      m <- mean(sub$annual_cases, na.rm = TRUE)
      if (m > 0) round(sd(sub$annual_cases, na.rm = TRUE) / m, 4)
      else NA_real_
    },
    .groups = "drop"
  ) %>%
  mutate(
    aapc = as.numeric(aapc),
    cv   = as.numeric(cv)
  )

# Verify key provinces against paper
cat("=== Feature Verification ===\n")
cat(sprintf("Yunnan:   cum_inc=%.2f (paper: 134.85), aapc=%.2f, cv=%.4f\n",
            provincial_summary$cum_incidence[provincial_summary$Province == "Yunnan"],
            provincial_summary$aapc[provincial_summary$Province == "Yunnan"],
            provincial_summary$cv[provincial_summary$Province == "Yunnan"]))
cat(sprintf("Guangxi:  cum_inc=%.2f (paper: 159.78), aapc=%.2f, cv=%.4f\n",
            provincial_summary$cum_incidence[provincial_summary$Province == "Guangxi"],
            provincial_summary$aapc[provincial_summary$Province == "Guangxi"],
            provincial_summary$cv[provincial_summary$Province == "Guangxi"]))
cat(sprintf("Guangdong: cum_inc=%.2f (paper: 32.92), aapc=%.2f, cv=%.4f\n",
            provincial_summary$cum_incidence[provincial_summary$Province == "Guangdong"],
            provincial_summary$aapc[provincial_summary$Province == "Guangdong"],
            provincial_summary$cv[provincial_summary$Province == "Guangdong"]))
cat(sprintf("Xinjiang:  cum_inc=%.2f (paper: 79.15), aapc=%.2f, cv=%.4f\n",
            provincial_summary$cum_incidence[provincial_summary$Province == "Xinjiang"],
            provincial_summary$aapc[provincial_summary$Province == "Xinjiang"],
            provincial_summary$cv[provincial_summary$Province == "Xinjiang"]))
cat(sprintf("Henan:    cum_inc=%.2f, aapc=%.2f (paper: 3.68), cv=%.4f\n",
            provincial_summary$cum_incidence[provincial_summary$Province == "Henan"],
            provincial_summary$aapc[provincial_summary$Province == "Henan"],
            provincial_summary$cv[provincial_summary$Province == "Henan"]))

# Save provincial summary
write.csv(provincial_summary, "provinces_summary_updated.csv", row.names = FALSE)

# Prepare features for clustering (z-score standardization)
features <- provincial_summary %>%
  select(cum_incidence, aapc, cv) %>%
  scale()

# Save cluster data
cluster_data <- as.data.frame(features)
cluster_data$Province <- provincial_summary$Province
write.csv(cluster_data, "cluster_data_updated.csv", row.names = FALSE)

# =============================================================================
# 3. Determine Optimal Number of Clusters
# =============================================================================

# Elbow method
set.seed(42)
wss_values <- sapply(1:10, function(k) {
  kmeans(features, k, nstart = 25)$tot.withinss
})

# Silhouette method
silhouette_scores <- sapply(2:10, function(k) {
  km <- kmeans(features, k, nstart = 25)
  ss <- silhouette(km$cluster, dist(features))
  mean(ss[, 3])
})

cat("\n=== Silhouette Scores ===\n")
print(silhouette_scores)

# Optimal k based on silhouette (k=5)
optimal_k <- 5

# =============================================================================
# 4. K-means Clustering with k=5
# =============================================================================

set.seed(42)
km_result <- kmeans(features, centers = optimal_k, nstart = 25, iter.max = 100)

# Add cluster assignments to provincial summary
provincial_summary$cluster <- factor(km_result$cluster)

# Save clustering results
cluster_result <- provincial_summary %>%
  select(Province, cluster, total_cases, cum_incidence, aapc, cv)
write.csv(cluster_result, "cluster_result_updated.csv", row.names = FALSE)

# =============================================================================
# 5. Cluster Interpretation
# =============================================================================

# Calculate cluster characteristics
cluster_chars <- provincial_summary %>%
  group_by(cluster) %>%
  summarise(
    n_provinces     = n(),
    provinces       = paste(Province, collapse = ", "),
    mean_incidence  = round(mean(cum_incidence, na.rm = TRUE), 2),
    sd_incidence    = round(sd(cum_incidence,   na.rm = TRUE), 2),
    mean_aapc       = round(mean(aapc,          na.rm = TRUE), 2),
    mean_cv         = round(mean(cv,            na.rm = TRUE), 4),
    total_cases     = sum(total_cases),
    .groups = "drop"
  ) %>%
  arrange(cluster)

cat("\n=== Cluster Characteristics ===\n")
print(cluster_chars)

# =============================================================================
# 6. Visualization - Figure 2: Clustering Results
# =============================================================================

# Color palette
colors <- c(
  primary = "#2E86AB",
  secondary = "#E94F37",
  tertiary = "#44AF69",
  quaternary = "#F18F01",
  quinary = "#9B59B6",
  gray = "#6C757D"
)

# PCA for visualization (2D projection only; clustering done on original 3D space)
pca_result <- prcomp(features, scale. = TRUE)
pca_data <- as.data.frame(pca_result$x[, 1:2])
pca_data$cluster <- factor(km_result$cluster)
pca_data$Province <- provincial_summary$Province

# Create clustering plot
p <- ggplot(pca_data, aes(x = PC1, y = PC2, color = cluster, label = Province)) +
  geom_point(size = 4, alpha = 0.8) +
  stat_ellipse(aes(fill = cluster), geom = "polygon", alpha = 0.1, level = 0.95) +
  geom_text(vjust = -0.8, hjust = 0.5, size = 2.5, check_overlap = TRUE) +
  scale_color_manual(values = c(colors["primary"], colors["secondary"],
                                colors["tertiary"], colors["quaternary"], colors["quinary"])) +
  scale_fill_manual(values = c(colors["primary"], colors["secondary"],
                               colors["tertiary"], colors["quaternary"], colors["quinary"])) +
  labs(
    title = "K-means Clustering of Provincial HIV/AIDS Epidemic Patterns",
    subtitle = "Five clusters identified based on cumulative incidence, AAPC, and coefficient of variation",
    x = paste0("PC1 (", round(summary(pca_result)$importance[2, 1] * 100, 1), "% variance)"),
    y = paste0("PC2 (", round(summary(pca_result)$importance[2, 2] * 100, 1), "% variance)"),
    color = "Cluster",
    fill = "Cluster"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5, size = 11, color = "gray40"),
    legend.position = "right"
  )

ggsave("Figure2_Clustering_Results.png", p, width = 10, height = 8, dpi = 300)

# =============================================================================
# 7. Additional Visualization - Cluster Characteristics
# =============================================================================

# Bar plot of cluster mean cumulative incidence
p2 <- ggplot(cluster_chars, aes(x = cluster, y = mean_incidence, fill = cluster)) +
  geom_bar(stat = "identity", alpha = 0.8) +
  geom_errorbar(aes(ymin = mean_incidence - sd_incidence,
                    ymax = mean_incidence + sd_incidence), width = 0.2) +
  scale_fill_manual(values = c(colors["primary"], colors["secondary"],
                               colors["tertiary"], colors["quaternary"], colors["quinary"])) +
  labs(
    title = "Average Cumulative Incidence by Cluster",
    subtitle = "Error bars represent within-cluster standard deviation",
    x = "Cluster",
    y = "Cumulative Incidence (per 100,000 population)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5, size = 11, color = "gray40"),
    legend.position = "none"
  )

ggsave("Figure2b_Cluster_Incidence.png", p2, width = 8, height = 6, dpi = 300)

# Bar plot of cluster mean AAPC
p3 <- ggplot(cluster_chars, aes(x = cluster, y = mean_aapc, fill = cluster)) +
  geom_bar(stat = "identity", alpha = 0.8) +
  scale_fill_manual(values = c(colors["primary"], colors["secondary"],
                               colors["tertiary"], colors["quaternary"], colors["quinary"])) +
  labs(
    title = "Average AAPC by Cluster",
    subtitle = "Average Annual Percent Change (2005-2020)",
    x = "Cluster",
    y = "Mean AAPC (%)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5, size = 11, color = "gray40"),
    legend.position = "none"
  )

ggsave("Figure2c_Cluster_AAPC.png", p3, width = 8, height = 6, dpi = 300)

# =============================================================================
# 8. Cluster Validation Metrics
# =============================================================================

# Silhouette score
sil <- silhouette(km_result$cluster, dist(features))
avg_sil <- mean(sil[, 3])
cat(sprintf("\n=== Cluster Validation ===\n"))
cat(sprintf("Average Silhouette Width: %.3f\n", avg_sil))

# Dunn index
dunn_index <- function(data, clusters) {
  dist_mat <- dist(data)
  cluster_ids <- unique(clusters)

  # Inter-cluster distance (minimum)
  inter_dist <- Inf
  for (i in 1:(length(cluster_ids) - 1)) {
    for (j in (i + 1):length(cluster_ids)) {
      idx_i <- which(clusters == cluster_ids[i])
      idx_j <- which(clusters == cluster_ids[j])
      min_dist <- min(as.matrix(dist_mat)[idx_i, idx_j])
      if (min_dist < inter_dist) inter_dist <- min_dist
    }
  }

  # Intra-cluster distance (maximum diameter)
  intra_dist <- 0
  for (k in cluster_ids) {
    idx_k <- which(clusters == k)
    if (length(idx_k) > 1) {
      max_dist <- max(as.matrix(dist_mat)[idx_k, idx_k])
      if (max_dist > intra_dist) intra_dist <- max_dist
    }
  }

  return(inter_dist / intra_dist)
}

dunn <- dunn_index(features, km_result$cluster)
cat(sprintf("Dunn Index: %.3f\n", dunn))

# =============================================================================
# End of Script
# =============================================================================
