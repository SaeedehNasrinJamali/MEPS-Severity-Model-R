# scripts/03_model.R

# Load cleaned data
dat <- readRDS("outputs/MEPS_clean.rds")

# ---- Train/test split (reuse if it already exists) ----
if (file.exists("outputs/split_idx.rds")) {
  idx <- readRDS("outputs/split_idx.rds")
  train_idx <- idx$train_idx
  test_idx  <- idx$test_idx
} else {
  set.seed(123)
  split <- caTools::sample.split(dat$TOTEXP20_winsorized, SplitRatio = 0.7)
  train_idx <- which(split == TRUE)
  test_idx  <- which(split == FALSE)
  dir.create("outputs", showWarnings = FALSE)
  saveRDS(list(train_idx = train_idx, test_idx = test_idx), "outputs/split_idx.rds")
}

training_set <- dat[train_idx, ]
testing_set  <- dat[test_idx,  ]

# ---- GLM (Gamma with log link): stepwise from cancer/utilization-free full model ----

# 1) Null model
null_model <- glm(
  TOTEXP20_winsorized ~ 1,
  family = Gamma(link = "log"),
  data   = training_set
)

# 2) Full model (ONLY variables that exist after 02_clean.R)
full_model <- glm(
  TOTEXP20_winsorized ~
    AGELAST + SEX + INSCOV20 + RACEV1X + ADBMI42 + FAMINC20 +
    OFTSMK53 + CHDDX + ASTHDX + DIABDX_M18 + HIBPDX + MIDX + EMPHDX,
  family = Gamma(link = "log"),
  data   = training_set
)

# 3) Stepwise selection (robust; falls back to full_model if needed)
stepwise_model <- tryCatch(
  step(
    object    = full_model,
    scope     = list(lower = formula(null_model), upper = formula(full_model)),
    direction = "backward",
    trace     = 0
  ),
  error = function(e) {
    message("step() failed; using full_model instead: ", e$message)
    full_model
  }
)

# ---- Save model and diagnostics ----
dir.create("outputs", showWarnings = FALSE)
saveRDS(stepwise_model, "outputs/MEPS_glm_stepwise.rds")

# Print a summary to console
print(summary(stepwise_model))

# Pseudo R^2 (McFadden, adjusted, deviance-based)
LL_null <- as.numeric(logLik(null_model))
LL_mod  <- as.numeric(logLik(stepwise_model))
k <- length(coef(stepwise_model))

pseudo_r2 <- data.frame(
  R2_McFadden     = 1 - (LL_mod / LL_null),
  R2_McFadden_adj = 1 - ((LL_mod - k) / LL_null),
  R2_deviance     = 1 - deviance(stepwise_model) / deviance(null_model)
)
write.csv(pseudo_r2, "outputs/pseudo_r2.csv", row.names = FALSE)

# Optional VIF diagnostics 
vif_ok <- TRUE
vifs <- tryCatch(car::vif(stepwise_model), error = function(e) { vif_ok <<- FALSE; e })
if (vif_ok) write.csv(as.data.frame(vifs), "outputs/vif.csv")

