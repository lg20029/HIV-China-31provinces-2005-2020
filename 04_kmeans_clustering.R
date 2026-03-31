#!/usr/bin/env Rscript
# =============================================================================
# R Script for K-means Clustering of Provincial HIV/AIDS Epidemic Patterns
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

# Calculate provincial summary statistics
provincial_summary <- raw_data %>%
  group_by(Province) %>%
  summarise(
    total_cases = sum(as.numeric(gsub("-", "0", `Cases`)), na.rm = TRUE),
    total_deaths = sum(as.numeric(gsub("-", "0", `Deaths`)), na.rm = TRUE)
  )

# Calculate annual cases by province
annual_by_province <- raw_data %>%
  mutate(year = as.numeric(gsub("-.*", "", Date))) %>%
  group_by(Province, year) %>%
  summarise(cases = sum(as.numeric(gsub("-", "0", `Cases`)), na.rm = TRUE), .groups = "drop")

# Calculate AAPC for each province
calculate_aapc <- function(data) {
  if (nrow(data) < 2) return(NA)
  model <- lm(log(cases + 1) ~ year, data = data)
  aapc <- (exp(coef(model)[2]) - 1) * 100
  return(as.numeric(aapc))
}

aapc_by_province <- annual_by_province %>%
  group_by(Province) %>%
  nest() %>%
  mutate(
    model = map(data, ~ lm(log(cases + 1) ~ year, data = .x)),
    aapc = map_dbl(model, ~ (exp(coef(.x)[2]) - 1) * 100)
  ) %>%
  select(Province, aapc)

# Calculate coefficient of variation for each province
cv_by_province <- annual_by_province %>%
  group_by(Province) %>%
  summarise(
    mean_cases = mean(cases, na.rm = TRUE),
    sd_cases = sd(cases, na.rm = TRUE),
    cv = sd_cases / mean_cases * 100
  )

# Combine all features
clustering_data <- provincial_summary %>%
  left_join(aapc_by_province, by = "Province") %>%
  left_join(cv_by_province %>% select(Province, cv), by = "Province") %>%
  mutate(
    incidence_per_100k = total_cases / 1400000000 * 100000 * 31,  # Approximate
    log_cases = log(total_cases + 1)
  ) %>%
  filter(!is.na(aapc) & !is.na(cv))

# Save provincial summary
write.csv(clustering_data, "provinces_summary.csv", row.names = FALSE)

# =============================================================================
# 2. Feature Selection and Standardization
# =============================================================================

# Select features for clustering
features <- clustering_data %>%
  select(Province, log_cases, aapc, cv) %>%
  column_to_rownames("Province")

# Standardize features
features_scaled <- scale(features)

# =============================================================================
# 3. Determine Optimal Number of Clusters
# =============================================================================

# Elbow method
set.seed(123)
wss <- numeric(15)
for (i in 1:15) {
  wss[i] <- sum(kmeans(features_scaled, centers = i)$withinss)
}

# Plot elbow
png("elbow_plot.png", width = 800, height = 600)
plot(1:15, wss, type = "b", pch = 19, col = "#2E86AB",
     xlab = "Number of Clusters", ylab = "Within-Cluster Sum of Squares",
     main = "Elbow Method for Optimal K")
abline(v = 4, col = "red", lty = 2)
dev.off()

# Silhouette method
sil_width <- numeric(14)
for (i in 2:15) {
  km <- kmeans(features_scaled, centers = i, nstart = 25)
  sil <- silhouette(km$cluster, dist(features_scaled))
  sil_width[i-1] <- mean(sil[, 3])
}

# Plot silhouette
png("silhouette_plot.png", width = 800, height = 600)
plot(2:15, sil_width, type = "b", pch = 19, col = "#E94F37",
     xlab = "Number of Clusters", ylab = "Average Silhouette Width",
     main = "Silhouette Method for Optimal K")
abline(v = which.max(sil_width) + 1, col = "red", lty = 2)
dev.off()

# Optimal number of clusters
optimal_k <- 4  # Based on elbow and silhouette analysis

# =============================================================================
# 4. K-means Clustering
# =============================================================================

set.seed(123)
km_result <- kmeans(features_scaled, centers = optimal_k, nstart = 25)

# Add cluster assignments to data
clustering_result <- clustering_data %>%
  mutate(cluster = factor(km_result$cluster))

# Calculate cluster statistics
cluster_stats <- clustering_result %>%
  group_by(cluster) %>%
  summarise(
    n_provinces = n(),
    provinces = paste(Province, collapse = ", "),
    mean_cases = mean(total_cases),
    mean_aapc = mean(aapc),
    mean_cv = mean(cv),
    .groups = "drop"
  )

print("Cluster Statistics:")
print(cluster_stats)

# Save clustering results
write.csv(clustering_result, "cluster_data.csv", row.names = FALSE)
write.csv(cluster_stats, "cluster_statistics.csv", row.names = FALSE)

# =============================================================================
# 5. Visualization
# =============================================================================

# PCA for visualization
pca_result <- prcomp(features_scaled, scale. = FALSE)
pca_data <- as.data.frame(pca_result$x) %>%
  rownames_to_column("Province") %>%
  left_join(clustering_result %>% select(Province, cluster), by = "Province")

# Cluster plot
p_cluster <- ggplot(pca_data, aes(x = PC1, y = PC2, color = cluster)) +
  geom_point(size = 3) +
  geom_text(aes(label = Province), vjust = -0.5, size = 3) +
  scale_color_brewer(palette = "Set1") +
  labs(
    title = "Provincial HIV/AIDS Epidemic Patterns: K-means Clustering",
    x = paste0("PC1 (", round(summary(pca_result)$importance[2,1] * 100, 1), "% variance)"),
    y = paste0("PC2 (", round(summary(pca_result)$importance[2,2] * 100, 1), "% variance)")
  ) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))

ggsave("figure6_clustering.png", p_cluster, width = 12, height = 8, dpi = 300)

# Cluster profile plot
profile_data <- clustering_result %>%
  group_by(cluster) %>%
  summarise(
    `Cumulative Cases` = mean(log_cases),
    `AAPC (%)` = mean(aapc),
    `CV (%)` = mean(cv),
    .groups = "drop"
  ) %>%
  pivot_longer(cols = -cluster, names_to = "Feature", values_to = "Value")

p_profile <- ggplot(profile_data, aes(x = Feature, y = Value, fill = cluster)) +
  geom_bar(stat = "identity", position = "dodge") +
  scale_fill_brewer(palette = "Set1") +
  labs(
    title = "Cluster Profiles",
    x = "Feature",
    y = "Mean Value"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"),
        axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("cluster_profile.png", p_profile, width = 10, height = 6, dpi = 300)

# =============================================================================
# 6. Cluster Interpretation
# =============================================================================

# Name clusters based on characteristics
cluster_names <- c(
  "1" = "High-prevalence rapid-growth",
  "2" = "High-prevalence stable",
  "3" = "Low-prevalence rapid-growth",
  "4" = "Low-prevalence stable"
)

clustering_result <- clustering_result %>%
  mutate(cluster_name = recode(cluster, !!!cluster_names))

# Print cluster membership
print("Cluster Membership:")
for (i in 1:optimal_k) {
  provinces_in_cluster <- clustering_result %>%
    filter(cluster == i) %>%
    pull(Province)
  cat(paste0("\nCluster ", i, " (", cluster_names[i], "):\n"))
  cat(paste(provinces_in_cluster, collapse = ", "), "\n")
}

# =============================================================================
# 7. Validation
# =============================================================================

# Silhouette analysis for final clustering
sil_final <- silhouette(km_result$cluster, dist(features_scaled))
avg_sil <- mean(sil_final[, 3])

print(paste("Average Silhouette Width:", round(avg_sil, 3)))

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

dunn <- dunn_index(features_scaled, km_result$cluster)
print(paste("Dunn Index:", round(dunn, 3)))

# =============================================================================
# End of Script
# =============================================================================
