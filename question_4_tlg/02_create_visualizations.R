# ------------------------------------------------------------------------------
# Question 4.2: adverse event visualisations with {ggplot2}
#   Plot 1: AE severity distribution by treatment arm (stacked bar)
#   Plot 2: Top 10 most frequent AEs with 95% Clopper-Pearson CIs for the
#           percentage of subjects affected
# Input : pharmaverseadam::adae (TRTEMFL == "Y")
# Output: question_4_tlg/output/ae_severity_by_treatment.png
#         question_4_tlg/output/top10_ae_incidence.png
# Run from the repository root:  Rscript question_4_tlg/02_create_visualizations.R
# ------------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
})

out_dir <- "question_4_tlg/output"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

teae <- pharmaverseadam::adae %>%
  filter(TRTEMFL == "Y") %>%
  mutate(AESEV = factor(AESEV, levels = c("MILD", "MODERATE", "SEVERE")))

# ---- Plot 1: severity distribution by treatment ---------------------------
sev_counts <- teae %>% count(ACTARM, AESEV, name = "n")

p1 <- ggplot(sev_counts, aes(x = ACTARM, y = n, fill = AESEV)) +
  geom_col(position = "stack") +
  scale_fill_manual(values = c(MILD = "#F8766D", MODERATE = "#00BA38", SEVERE = "#619CFF")) +
  labs(
    title = "AE severity distribution by treatment",
    x = "Treatment Arm", y = "Count of AEs", fill = "Severity/Intensity"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "right")

ggsave(file.path(out_dir, "ae_severity_by_treatment.png"), p1,
       width = 8, height = 5, dpi = 150, bg = "white")

# ---- Plot 2: top 10 AEs with Clopper-Pearson 95% CI -----------------------
# Incidence is the number of subjects with at least one TEAE of that term,
# divided by all subjects with any TEAE.
n_subj <- n_distinct(teae$USUBJID)

top10 <- teae %>%
  distinct(USUBJID, AETERM) %>%          # one row per subject-term
  count(AETERM, name = "n_subj_ae") %>%
  arrange(desc(n_subj_ae), AETERM) %>%
  slice_head(n = 10) %>%
  rowwise() %>%
  mutate(
    pct   = 100 * n_subj_ae / n_subj,
    ci    = list(binom.test(n_subj_ae, n_subj)$conf.int),  # exact (Clopper-Pearson)
    lower = 100 * ci[1],
    upper = 100 * ci[2]
  ) %>%
  ungroup() %>%
  select(-ci) %>%
  mutate(AETERM = factor(AETERM, levels = rev(AETERM)))    # most frequent on top

p2 <- ggplot(top10, aes(x = pct, y = AETERM)) +
  geom_errorbar(aes(xmin = lower, xmax = upper), width = 0.25) +   # horizontal CI whiskers
  geom_point(size = 3) +
  scale_x_continuous(labels = function(x) paste0(x, "%")) +
  expand_limits(x = 0) +                                          # anchor the axis at 0%
  labs(
    title = "Top 10 Most Frequent Adverse Events",
    subtitle = sprintf("n = %d subjects with a treatment-emergent AE; 95%% Clopper-Pearson CIs", n_subj),
    x = "Percentage of Patients (%)", y = NULL
  ) +
  theme_minimal(base_size = 12)

ggsave(file.path(out_dir, "top10_ae_incidence.png"), p2,
       width = 8, height = 5, dpi = 150, bg = "white")

# ---- Checks ----------------------------------------------------------------
stopifnot(
  file.exists(file.path(out_dir, "ae_severity_by_treatment.png")),
  file.exists(file.path(out_dir, "top10_ae_incidence.png")),
  nrow(top10) == 10,
  as.character(top10$AETERM[1]) == "PRURITUS",   # most frequent term
  levels(top10$AETERM)[10] == "PRURITUS"         # and therefore the top row of the plot
)
cat("Saved two PNG files to", out_dir, "\n")
print(top10 %>% select(AETERM, n_subj_ae, pct, lower, upper))
