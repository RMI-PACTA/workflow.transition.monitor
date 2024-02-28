logger::log_threshold(Sys.getenv("LOG_LEVEL", ifelse(interactive(), "FATAL", "INFO")))
logger::log_formatter(logger::formatter_glue)

logger::log_info("Loading libraries")
suppressPackageStartupMessages({
  library(pacta.portfolio.utils)
  library(pacta.portfolio.import)
  library(pacta.portfolio.audit)
  library(dplyr)
  library(here)
  library(glue)
})

logger::log_info("web_tool_script_1.R (build: \"{get_build_version_msg()}\").")

if (!exists("portfolio_name_ref_all")) {
  portfolio_name_ref_all <- "1234"
  logger::log_warn("portfolio_name_ref_all not defined, using default value: {portfolio_name_ref_all}.")
}

portfolio_root_dir <- "working_dir"
logger::log_debug("portfolio_root_dir: \"{portfolio_root_dir}\".")

logger::log_info("Setting up project.")
setup_project()

working_location <- file.path(working_location)
logger::log_debug("working_location: \"{working_location}\".")

logger::log_info("Setting webtool paths.")
set_webtool_paths(portfolio_root_dir)

portfolio_parameters_file <- file.path(
  par_file_path,
  paste0(portfolio_name_ref_all, "_PortfolioParameters.yml")
)
logger::log_info(
  "Setting portfolio parameters from file: \"{portfolio_parameters_file}\"."
)
set_portfolio_parameters(file_path = portfolio_parameters_file)

project_parameters_file <- file.path(
  working_location,
  "parameter_files", paste0("ProjectParameters_", project_code, ".yml")
)
logger::log_info(
  "Setting project parameters from file: \"{project_parameters_file}\"."
)
set_project_parameters(project_parameters_file)

# need to define an alternative location for data files
logger::log_info("Setting analysis inputs path to \"{data_location_ext}\".")
analysis_inputs_path <- set_analysis_inputs_path(data_location_ext)

# To save, files need to go in the portfolio specific folder, created here
logger::log_info("Creating portfolio subfolders in \"{project_location}\".")
create_portfolio_subfolders(portfolio_name_ref_all = portfolio_name_ref_all, project_location = project_location)


# load necessary input data ----------------------------------------------------
logger::log_info("Loading input data.")

logger::log_info("Loading currencies data.")
currencies <- readRDS(file.path(analysis_inputs_path, "currencies.rds"))

logger::log_info("Loading fund data.")
fund_data <- readRDS(file.path(analysis_inputs_path, "fund_data.rds"))

logger::log_info("Loading total fund list.")
total_fund_list <- readRDS(file.path(analysis_inputs_path, "total_fund_list.rds"))

logger::log_info("Loading ISIN to fund table.")
isin_to_fund_table <- readRDS(file.path(analysis_inputs_path, "isin_to_fund_table.rds"))

logger::log_info("Loading financial data.")
fin_data <- readRDS(file.path(analysis_inputs_path, "financial_data.rds"))

logger::log_info("Loading entity info.")
entity_info <- get_entity_info(dir = analysis_inputs_path)

logger::log_info("Loading ABCD equity flags.")
abcd_flags_equity <- readRDS(file.path(analysis_inputs_path, "abcd_flags_equity.rds"))

logger::log_info("Loading ABCD bond flags.")
abcd_flags_bonds <- readRDS(file.path(analysis_inputs_path, "abcd_flags_bonds.rds"))

if (inc_emission_factors) {
  logger::log_info("Loading entity emission intensity data.")
  entity_emission_intensities <- readRDS(
    file.path(analysis_inputs_path, "iss_entity_emission_intensities.rds")
  )

  logger::log_info("Loading average sector emission intensity data.")
  average_sector_emission_intensities <- readRDS(
    file.path(analysis_inputs_path, "iss_average_sector_emission_intensities.rds")
  )
} else {
  logger::log_info("Emission intensities not included.")
}

logger::log_info("Input data loaded.")

# Portfolios -------------------------------------------------------------------

logger::log_info("Loading portfolio data.")
abort_if_file_doesnt_exist(
  here::here(
    "working_dir", "20_Raw_Inputs", glue::glue("{portfolio_name_ref_all}.csv")
  )
)
portfolio_raw <- get_input_files(portfolio_name_ref_all, project_location = project_location)

logger::log_info("Processing raw portfolio.")
portfolio <- process_raw_portfolio(
  portfolio_raw = portfolio_raw,
  fin_data = fin_data,
  fund_data = fund_data,
  entity_info = entity_info,
  currencies = currencies,
  total_fund_list = total_fund_list,
  isin_to_fund_table = isin_to_fund_table
)

# FIXME: this is necessary because pacta.portfolio.allocate::add_revenue_split()
#  was removed in #142, but later we realized that it had a sort of hidden
#  behavior where if there is no revenue data it maps the security_mapped_sector
#  column of the portfolio data to financial_sector, which is necessary later
portfolio <-
  portfolio %>%
  mutate(
    has_revenue_data = FALSE,
    financial_sector = .data$security_mapped_sector
  )

logger::log_info("Creating portfolio ABCD flags.")
portfolio <- create_ald_flag(portfolio, comp_fin_data = abcd_flags_equity, debt_fin_data = abcd_flags_bonds)

logger::log_debug("adding flags to portfolio.")
portfolio_total <- add_portfolio_flags(portfolio)

logger::log_info("Creating portfolio summary.")
portfolio_overview <- portfolio_summary(portfolio_total)

logger::log_info("Creating audit file.")
audit_file <- create_audit_file(portfolio_total, has_revenue)

if (inc_emission_factors) {
  logger::log_info("Calculating portfolio financed emissions.")
  emissions_totals <- calculate_portfolio_financed_emissions(
    portfolio_total,
    entity_info,
    entity_emission_intensities,
    average_sector_emission_intensities
  )
} else {
  logger::log_info("Bypassing financed emissions calculation.")
}


# Saving -----------------------------------------------------------------------

proc_input_path_ <- file.path(proc_input_path, portfolio_name_ref_all)
logger::log_debug("Processed inputs path: \"{proc_input_path_}\".")

logger::log_info("Exporting audit information to \"{proc_input_path}\".")
export_audit_information_data(
  audit_file_ = audit_file %>% filter(portfolio_name == portfolio_name),
  portfolio_total_ = portfolio_total %>% filter(portfolio_name == portfolio_name),
  folder_path = proc_input_path_
)

total_portfolio_path <- file.path(proc_input_path_, "total_portfolio.rds")
logger::log_info("Saving portfolio totals to \"{total_portfolio_path}\".")
save_if_exists(portfolio_total, portfolio_name, total_portfolio_path)

overview_portfolio_path <- file.path(proc_input_path_, "overview_portfolio.rds")
logger::log_info("Saving portfolio overview to \"{overview_portfolio_path}\".")
save_if_exists(portfolio_overview, portfolio_name, overview_portfolio_path)

audit_file_rds_path <- file.path(proc_input_path_, "audit_file.rds")
logger::log_info("Saving audit file (rds) to \"{audit_file_rds_path}\".")
save_if_exists(audit_file, portfolio_name, audit_file_rds_path)

audit_file_csv_path <- file.path(proc_input_path_, "audit_file.csv")
logger::log_info("Saving audit file (csv) to \"{audit_file_csv_path}\".")
save_if_exists(audit_file, portfolio_name, audit_file_csv_path, csv_or_rds = "csv")

if (inc_emission_factors) {
  emissions_totals_path <- file.path(proc_input_path_, "emissions.rds")
  logger::log_info("Saving emissions totals to \"{emissions_totals_path}\".")
  save_if_exists(emissions_totals, portfolio_name, emissions_totals_path)
} else {
  logger::log_info("Bypassing saving emissions totals.")
}

logger::log_trace("removing R objects.")
remove_if_exists(portfolio_total)
remove_if_exists(portfolio)
remove_if_exists(audit_file)

logger::log_info("web_tool_script_1.R finished.")
