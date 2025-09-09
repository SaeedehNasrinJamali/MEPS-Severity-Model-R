# scripts/03_model.R

dat <- readRDS("outputs/MEPS_clean.rds")

# Reuse the same split everywhere 
if (file.exists("outputs/split_idx.rds")) {
  idx <- readRDS("outputs/split_idx.rds")
  train_idx <- idx$train_idx; test_idx <- idx$test_idx
} else {
  set.seed(123)
  split <- caTools::sample.split(dat$TOTEXP20_winsorized, SplitRatio = 0.7)
  train_idx <- which(split == TRUE); test_idx <- which(split == FALSE)
  saveRDS(list(train_idx=train_idx, test_idx=test_idx), "outputs/split_idx.rds")
}

training_set <- dat[train_idx, ]
testing_set  <- dat[test_idx, ]

# ----- STEPWISE MODEL SELECTION BLOCK -----

# 1) Null model
null_model <- glm(TOTEXP20_winsorized ~ 1,
                  family = Gamma(link = "log"),
                  data = training_set)

# 2) Full model
full_model <- glm(
  TOTEXP20_winsorized ~ AGELAST + SEX + INSCOV20 +
    RACEV1X + ADBMI42 + OFTSMK53 + CHDDX + ASTHDX + DIABDX_M18 +
    HIBPDX + MIDX + EMPHDX + CANCERDX + IPDIS20 + OBTOTV20 +
    OPTOTV20 + HHTOTD20 + ERTOT20 + RXTOT20 +
    CACOLON_flag + CALUNG_flag + CALYMPH_flag + CAMELANO_flag + CAOTHER_flag +
    CAPROSTA_flag + CASKINDK_flag + CASKINNM_flag + CAUTERUS_flag +
    CABLADDR_flag + CABREAST_flag + FAMINC20,
  family = Gamma(link = "log"),
  data = training_set
)

# 3) Stepwise selection (backward is fine)
stepwise_model <- step(full_model, direction = "backward", trace = 0)

# Save final model
dir.create("outputs", showWarnings = FALSE)
saveRDS(stepwise_model, "outputs/MEPS_glm_stepwise.rds")

# Print a summary to console
print(summary(stepwise_model))

# ----- Pseudo R^2 (McFadden / adjusted / deviance-based) -----
LL_null <- as.numeric(logLik(null_model))
LL_mod  <- as.numeric(logLik(stepwise_model))
k <- length(coef(stepwise_model))

pseudo_r2 <- data.frame(
  R2_McFadden      = 1 - (LL_mod / LL_null),
  R2_McFadden_adj  = 1 - ((LL_mod - k) / LL_null),
  R2_deviance      = 1 - deviance(stepwise_model) / deviance(null_model)
)
write.csv(pseudo_r2, "outputs/pseudo_r2.csv", row.names = FALSE)

# ----- (Optional) VIF diagnostics -----
# Requires library(car) loaded in 01_setup.R
vif_ok <- TRUE
vifs <- tryCatch(car::vif(stepwise_model), error = function(e) { vif_ok <<- FALSE; e })
if (vif_ok) write.csv(as.data.frame(vifs), "outputs/vif.csv")
