suppressPackageStartupMessages({
  library(pacta.portfolio.utils)
  library(pacta.portfolio.import)
  library(pacta.portfolio.audit)
  library(cli)
  library(dplyr)
  library(here)
  library(glue)
})

cli::cli_h1("web_tool_script_1.R{get_build_version_msg()}")


if (!exists("portfolio_name_ref_all")) {
  portfolio_name_ref_all <- "1234"
}

portfolio_root_dir <- "working_dir"

setup_project()

working_location <- file.path(working_location)

set_webtool_paths(portfolio_root_dir)

set_portfolio_parameters(file_path = file.path(par_file_path, paste0(portfolio_name_ref_all, "_PortfolioParameters.yml")))

proj_param_filename <- ifelse(
  project_code == "GENERAL",
  paste0("ProjectParameters_", project_code, "_", port_holdings_date, ".yml"),
  proj_param_filename <- paste0("ProjectParameters_", project_code, ".yml")
)
project_config_path <- file.path(working_location, "parameter_files", proj_param_filename)
set_project_parameters(project_config_path)

# need to define an alternative location for data files
analysis_inputs_path <- set_analysis_inputs_path(data_location_ext)

# To save, files need to go in the portfolio specific folder, created here
create_portfolio_subfolders(portfolio_name_ref_all = portfolio_name_ref_all, project_location = project_location)

source("R/utils.R")
merge_configs_and_export_environment_info(
  portfolio_config_path = file.path(par_file_path, paste0(portfolio_name_ref_all, "_PortfolioParameters.yml")),
  project_config_path = project_config_path,
  data_manifest_path = file.path(analysis_inputs_path, "manifest.json"),
  dir = log_path,
  filename = "environment_info_webtool1.json"
)


# load necessary input data ----------------------------------------------------

currencies <- readRDS(file.path(analysis_inputs_path, "currencies.rds"))

fund_data <- readRDS(file.path(analysis_inputs_path, "fund_data.rds"))
total_fund_list <- readRDS(file.path(analysis_inputs_path, "total_fund_list.rds"))
isin_to_fund_table <- readRDS(file.path(analysis_inputs_path, "isin_to_fund_table.rds"))

fin_data <- readRDS(file.path(analysis_inputs_path, "financial_data.rds"))

entity_info <- get_entity_info(dir = analysis_inputs_path)

abcd_flags_equity <- readRDS(file.path(analysis_inputs_path, "abcd_flags_equity.rds"))
abcd_flags_bonds <- readRDS(file.path(analysis_inputs_path, "abcd_flags_bonds.rds"))

if (inc_emission_factors) {
  entity_emission_intensities <- readRDS(
    file.path(analysis_inputs_path, "iss_entity_emission_intensities.rds")
  )

  average_sector_emission_intensities <- readRDS(
    file.path(analysis_inputs_path, "iss_average_sector_emission_intensities.rds")
  )
}


# Portfolios -------------------------------------------------------------------

abort_if_file_doesnt_exist(
  here::here(
    "working_dir", "20_Raw_Inputs", glue::glue("{portfolio_name_ref_all}.csv")
  )
)
portfolio_raw <- get_input_files(portfolio_name_ref_all, project_location = project_location)

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

portfolio <- create_ald_flag(portfolio, comp_fin_data = abcd_flags_equity, debt_fin_data = abcd_flags_bonds)

portfolio_w_flags <- add_portfolio_flags(portfolio, currencies)

portfolio_overview <- portfolio_summary(portfolio_w_flags)

audit_file <- create_audit_file(portfolio_w_flags, has_revenue)

if (inc_emission_factors) {
  emissions_totals <- calculate_portfolio_financed_emissions(
    portfolio_w_flags,
    entity_info,
    entity_emission_intensities,
    average_sector_emission_intensities
  )
}

portfolio_total <- dplyr::filter(portfolio_w_flags, valid_input == TRUE)


# Saving -----------------------------------------------------------------------

proc_input_path_ <- file.path(proc_input_path, portfolio_name_ref_all)

export_audit_information_data(
  audit_file_ = audit_file %>% filter(portfolio_name == portfolio_name),
  portfolio_total_ = portfolio_total %>% filter(portfolio_name == portfolio_name),
  folder_path = proc_input_path_
)

save_if_exists(portfolio_total, portfolio_name, file.path(proc_input_path_, "total_portfolio.rds"))
save_if_exists(portfolio_overview, portfolio_name, file.path(proc_input_path_, "overview_portfolio.rds"))
save_if_exists(audit_file, portfolio_name, file.path(proc_input_path_, "audit_file.rds"))
save_if_exists(audit_file, portfolio_name, file.path(proc_input_path_, "audit_file.csv"), csv_or_rds = "csv")

if (inc_emission_factors) {
  save_if_exists(emissions_totals, portfolio_name, file.path(proc_input_path_, "emissions.rds"))
}

remove_if_exists(portfolio_w_flags)
remove_if_exists(portfolio_total)
remove_if_exists(portfolio)
remove_if_exists(audit_file)
