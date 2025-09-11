# scripts/02_clean.R
# (Assumes packages are loaded in scripts/01_setup.R)

# ---- Load & basic filters ----
data_path <- "data/H224.xlsx"
MEPS <- readxl::read_excel(data_path)
names(MEPS) <- trimws(names(MEPS))

# Keep adults with positive total expenditures
MEPS <- MEPS[MEPS$TOTEXP20 > 0, ]
MEPS <- MEPS[MEPS$AGELAST > 17, ]
cat("Rows after basic filters:", nrow(MEPS), "\n")

# ---- Variable selection (NO utilization, NO cancer) ----
MEPSSELECTED <- dplyr::select(
  MEPS,
  TOTEXP20,   # Target
  AGELAST, SEX, INSCOV20, RACEV1X, ADBMI42, FAMINC20, OFTSMK53,
  CHDDX, ASTHDX, DIABDX_M18, HIBPDX, MIDX, EMPHDX
)

# ---- Invalid codes -> NA (type-stable) ----
MEPSSELECTED <- MEPSSELECTED %>%
  dplyr::mutate(
    ADBMI42     = dplyr::if_else(ADBMI42 < 0, NA_real_, ADBMI42),
    CHDDX       = dplyr::if_else(CHDDX       %in% c(-1, -8),       NA_integer_, CHDDX),
    ASTHDX      = dplyr::if_else(ASTHDX      %in% c(-15, -8),      NA_integer_, ASTHDX),
    DIABDX_M18  = dplyr::if_else(DIABDX_M18  %in% c(-15, -8),      NA_integer_, DIABDX_M18),
    HIBPDX      = dplyr::if_else(HIBPDX      %in% c(-1, -8),       NA_integer_, HIBPDX),
    MIDX        = dplyr::if_else(MIDX        %in% c(-1, -8),       NA_integer_, MIDX),
    EMPHDX      = dplyr::if_else(EMPHDX      %in% c(-1, -8),       NA_integer_, EMPHDX),
    OFTSMK53    = dplyr::if_else(OFTSMK53    %in% c(-1, -7, -8),   NA_integer_, OFTSMK53),
    FAMINC20    = dplyr::if_else(FAMINC20    < 0,                  NA_real_,   FAMINC20)
  )

# ---- Factors with readable labels ----
MEPSSELECTED <- MEPSSELECTED %>%
  dplyr::mutate(
    SEX        = factor(SEX,        levels = c(1, 2), labels = c("Male","Female")),
    INSCOV20   = factor(INSCOV20,   levels = 1:3,     labels = c("Any private","Public only","Uninsured")),
    RACEV1X    = factor(RACEV1X,    levels = 1:5,     labels = c("White","Black","AI/AN","Asian","NH/PI")),
    OFTSMK53   = factor(OFTSMK53,   levels = 1:3,     labels = c("Every day","Some days","Not at all")),
    CHDDX      = factor(CHDDX,      levels = c(2,1),  labels = c("No CHD","Yes CHD")),
    ASTHDX     = factor(ASTHDX,     levels = c(2,1),  labels = c("No Asthma","Yes Asthma")),
    DIABDX_M18 = factor(DIABDX_M18, levels = c(2,1),  labels = c("No Diabetes","Yes Diabetes")),
    HIBPDX     = factor(HIBPDX,     levels = c(2,1),  labels = c("No HBP","Yes HBP")),
    MIDX       = factor(MIDX,       levels = c(2,1),  labels = c("No MI","Yes MI")),
    EMPHDX     = factor(EMPHDX,     levels = c(2,1),  labels = c("No Emphysema","Yes Emphysema"))
  )

# ---- Drop incomplete rows ----
MEPS_cc <- MEPSSELECTED[complete.cases(MEPSSELECTED), ]
cat("Rows after complete-cases drop:", nrow(MEPS_cc), "\n")

# ---- Winsorize target at p99 ----
TOTEXP20_99 <- stats::quantile(MEPS_cc$TOTEXP20, 0.99, na.rm = TRUE)
MEPS_w <- MEPS_cc %>%
  dplyr::mutate(TOTEXP20_winsorized = ifelse(TOTEXP20 > TOTEXP20_99, TOTEXP20_99, TOTEXP20))

# ---- Save cleaned data ----
dir.create("outputs", showWarnings = FALSE)
saveRDS(MEPS_w, "outputs/MEPS_clean.rds")
cat("Clean data saved to outputs/MEPS_clean.rds\n")
