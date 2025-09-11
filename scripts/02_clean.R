# scripts/02_clean.R
# (Assumes packages are loaded in scripts/01_setup.R)

# ---- Load & basic filters ----
data_path <- "data/H224.xlsx"        # <— relative path
MEPS <- readxl::read_excel(data_path)
names(MEPS) <- trimws(names(MEPS))

# Keep adults with positive total expenditures
MEPS <- MEPS[MEPS$TOTEXP20 > 0, ]
MEPS <- MEPS[MEPS$AGELAST > 17, ]

cat("Rows after basic filters:", nrow(MEPS), "\n")

# ---- Variable selection ----
MEPSSELECTED <- dplyr::select(
  MEPS,
  TOTEXP20,   # Target: total expenditures in 2020
  AGELAST,    # Age at end of 2020
  SEX,        # Gender
  INSCOV20,   # Insurance coverage in 2020
  RACEV1X,    # Race/ethnicity
  ADBMI42,    # BMI
  FAMINC20,   # Family income (2020)
  OFTSMK53,   # Smoking frequency

  # Chronic condition indicators (binary Yes/No)
  CHDDX,      # Coronary heart disease
  ASTHDX,     # Asthma
  DIABDX_M18, # Diabetes (merged)
  HIBPDX,     # High blood pressure
  MIDX,       # Myocardial infarction
  EMPHDX,     # Emphysema
  CANCERDX,   # Any cancer

  # Cancer site-specific flags (binary Yes/No)
  CACOLON,    # Colorectal cancer
  CALUNG,     # Lung cancer
  CALYMPH,    # Lymphoma
  CAMELANO,   # Melanoma
  CAOTHER,    # Other cancer
  CAPROSTA,   # Prostate cancer
  CASKINDK,   # Skin cancer (unknown type)
  CASKINNM,   # Skin cancer non-melanoma
  CAUTERUS,   # Uterine cancer
  CABLADDR,   # Bladder cancer
  CABREAST    # Breast cancer
)

MEPSSELECTED <- MEPSSELECTED %>%
  dplyr::select(
    -IPDIS20, -OBTOTV20, -OPTOTV20, -HHTOTD20, -ERTOT20, -RXTOT20,  # utilization
    -CACOLON, -CALUNG, -CALYMPH, -CAMELANO, -CAOTHER,              # site-specific
    -CAPROSTA, -CASKINDK, -CASKINNM, -CAUTERUS, -CABLADDR, -CABREAST
  )
# ---- Invalid codes -> NA ----
MEPSSELECTED <- MEPSSELECTED %>%
  dplyr::mutate(
    ADBMI42     = dplyr::if_else(ADBMI42 < 0, NA_real_, ADBMI42),
    CHDDX       = dplyr::if_else(CHDDX       %in% c(-1, -8),       NA, CHDDX),
    ASTHDX      = dplyr::if_else(ASTHDX      %in% c(-15, -8),      NA, ASTHDX),
    DIABDX_M18  = dplyr::if_else(DIABDX_M18  %in% c(-15, -8),      NA, DIABDX_M18),
    HIBPDX      = dplyr::if_else(HIBPDX      %in% c(-1, -8),       NA, HIBPDX),
    MIDX        = dplyr::if_else(MIDX        %in% c(-1, -8),       NA, MIDX),
    EMPHDX      = dplyr::if_else(EMPHDX      %in% c(-1, -8),       NA, EMPHDX),
    CANCERDX    = dplyr::if_else(CANCERDX    %in% c(-1, -15, -8),  NA, CANCERDX),
    OFTSMK53    = dplyr::if_else(OFTSMK53    %in% c(-1, -7, -8),   NA, OFTSMK53),
    HHTOTD20    = dplyr::if_else(HHTOTD20    < 0,                  NA_real_, HHTOTD20),
    FAMINC20    = dplyr::if_else(FAMINC20    < 0,                  NA_real_, FAMINC20)
  )

# ---- Factors with readable labels ----
MEPSSELECTED <- MEPSSELECTED %>%
  dplyr::mutate(
    SEX       = factor(SEX,       levels = c(1, 2), labels = c("Male","Female")),
    INSCOV20  = factor(INSCOV20,  levels = 1:3,     labels = c("Any private","Public only","Uninsured")),
    RACEV1X   = factor(RACEV1X,   levels = 1:5,     labels = c("White","Black","AI/AN","Asian","NH/PI")),
    OFTSMK53  = factor(OFTSMK53,  levels = 1:3,     labels = c("Every day","Some days","Not at all")),
    CHDDX     = factor(CHDDX,     levels = c(2,1),  labels = c("No CHD","Yes CHD")),
    ASTHDX    = factor(ASTHDX,    levels = c(2,1),  labels = c("No Asthma","Yes Asthma")),
    DIABDX_M18= factor(DIABDX_M18,levels = c(2,1),  labels = c("No Diabetes","Yes Diabetes")),
    HIBPDX    = factor(HIBPDX,    levels = c(2,1),  labels = c("No HBP","Yes HBP")),
    MIDX      = factor(MIDX,      levels = c(2,1),  labels = c("No MI","Yes MI")),
    EMPHDX    = factor(EMPHDX,    levels = c(2,1),  labels = c("No Emphysema","Yes Emphysema")),
    CANCERDX  = factor(CANCERDX,  levels = c(2,1),  labels = c("No Cancer","Yes Cancer"))
  )

# ---- Drop incomplete rows (baseline approach) ----
MEPSSELECTED_transformed <- MEPSSELECTED[complete.cases(MEPSSELECTED), ]
cat("Rows after complete-cases drop:", nrow(MEPSSELECTED_transformed), "\n")

# ---- Winsorize target at p99 ----
TOTEXP20_99 <- stats::quantile(MEPSSELECTED_transformed$TOTEXP20, 0.99, na.rm = TRUE)
MEPSSELECTED_winsorized <- MEPSSELECTED_transformed %>%
  dplyr::mutate(TOTEXP20_winsorized = ifelse(TOTEXP20 > TOTEXP20_99, TOTEXP20_99, TOTEXP20))

# ---- Save cleaned data for downstream scripts ----
dir.create("outputs", showWarnings = FALSE)
saveRDS(MEPSSELECTED_winsorized, "outputs/MEPS_clean.rds")

cat("Clean data saved to outputs/MEPS_clean.rds\n")

