options(stringsAsFactors = FALSE)

pkgs <- c(
  "readxl","dplyr","tidyr","readr","faraway","sandwich","lmtest",
  "fastDummies","corrplot","ggplot2","caTools","car","xgboost","caret"
)
# Optional for SHAP:
# pkgs <- c(pkgs, "shap")

to_install <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(to_install)) install.packages(to_install, dependencies = TRUE)
invisible(lapply(pkgs, library, character.only = TRUE))

print(sessionInfo())


