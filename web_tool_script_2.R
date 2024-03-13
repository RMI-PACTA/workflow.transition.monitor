logger::log_threshold(Sys.getenv("LOG_LEVEL", ifelse(interactive(), "FATAL", "INFO")))
logger::log_formatter(logger::formatter_glue)

logger::log_info("Loading libraries")
suppressPackageStartupMessages({
  library(pacta.portfolio.utils)
  library(pacta.portfolio.allocate)
  library(cli)
  library(dplyr)
})

logger::log_info("web_tool_script_2.R (build: \"{get_build_version_msg()}\").")

# Start run analysis -----------------------------------------------------------

if (!exists("portfolio_name_ref_all")) {
  portfolio_name_ref_all <- "1234"
  logger::log_warn("portfolio_name_ref_all not defined, using default value: {portfolio_name_ref_all}.")
}
if (!exists("portfolio_root_dir")) {
  portfolio_root_dir <- "working_dir"
  logger::log_warn("portfolio_root_dir not defined, using default value: {portfolio_root_dir}.")
}

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

# delete all results files within the current portfolio folder
logger::log_info("Deleting all existing results files within the current portfolio folder.")
unlink(file.path(results_path, portfolio_name_ref_all, "*"), force = TRUE, recursive = TRUE)

# run again so output folders are available after deleting past results
logger::log_info("Creating portfolio subfolders in \"{project_location}\".")
create_portfolio_subfolders(portfolio_name_ref_all)


# quit if there's no relevant PACTA assets -------------------------------------

total_portfolio_path <- file.path(proc_input_path, portfolio_name_ref_all, "total_portfolio.rds")
if (file.exists(total_portfolio_path)) {
  logger::log_info("Loading portfolio total data from \"{total_portfolio_path}\".")
  total_portfolio <- readRDS(total_portfolio_path)
  quit_if_no_pacta_relevant_data(total_portfolio)
} else {
  logger::log_warn("\"total_portfolio.rds\" file does not exist in the \"30_Processed_inputs\" directory.")
  warning("This is weird... the `total_portfolio.rds` file does not exist in the `30_Processed_inputs` directory.")
}


# Equity -----------------------------------------------------------------------

logger::log_info("Creating equity portfolio subset.")
port_raw_all_eq <- create_portfolio_subset(total_portfolio, "Equity")

if (inherits(port_raw_all_eq, "data.frame") && nrow(port_raw_all_eq) > 0) {
  logger::log_info("Equity data found. Starting equity calculations.")
  map_eq <- NA
  company_all_eq <- NA
  port_all_eq <- NA

  logger::log_info("Calculating weights for equity portfolio.")
  port_eq <- calculate_weights(port_raw_all_eq, "Equity")

  logger::log_info("Merging ABCD data from database.")
  port_eq <- merge_abcd_from_db(
    portfolio = port_eq,
    portfolio_type = "Equity",
    db_dir = analysis_inputs_path,
    equity_market_list = equity_market_list,
    scenario_sources_list = scenario_sources_list,
    scenario_geographies_list = scenario_geographies_list,
    sector_list = sector_list,
    id_col = "id"
  )

  # Portfolio weight methodology
  logger::log_info("Calculating portfolio weight allocation.")
  port_pw_eq <- port_weight_allocation(port_eq)

  logger::log_info("Aggregating company data based on portfolio weights.")
  company_pw_eq <- aggregate_company(port_pw_eq)

  logger::log_info("Aggregating portfolio data based on portfolio weights.")
  port_pw_eq <- aggregate_portfolio(company_pw_eq)

  # Ownership weight methodology
  logger::log_info("Calculating ownership allocation.")
  port_own_eq <- ownership_allocation(port_eq)

  logger::log_info("Aggregating company data based on ownership weights.")
  company_own_eq <- aggregate_company(port_own_eq)

  logger::log_info("Aggregating portfolio data based on ownership weights.")
  port_own_eq <- aggregate_portfolio(company_own_eq)

  # Create combined outputs
  logger::log_info("Combining portfolio and ownership weights for company data.")
  company_all_eq <- bind_rows(company_pw_eq, company_own_eq)

  logger::log_info("Combining portfolio and ownership weights for portfolio data.")
  port_all_eq <- bind_rows(port_pw_eq, port_own_eq)

  if (has_map) {
    logger::log_info("Merging in geography data.")
    abcd_raw_eq <- get_abcd_raw("Equity")
    map_eq <- merge_in_geography(company_all_eq, abcd_raw_eq)
    rm(abcd_raw_eq)

    map_eq <- aggregate_map_data(map_eq)
  } else {
    logger::log_info("No map data available. Skipping map calculations.")
  }

  # Technology Share Calculation
  logger::log_info("Calculating portfolio technology share.")
  port_all_eq <- calculate_technology_share(port_all_eq)

  logger::log_info("Calculating company technology share.")
  company_all_eq <- calculate_technology_share(company_all_eq)

  # Scenario alignment calculations
  logger::log_info("Calculating scenario alignment for portfolio data.")
  port_all_eq <- calculate_scenario_alignment(port_all_eq)

  logger::log_info("Calculating scenario alignment for company data.")
  company_all_eq <- calculate_scenario_alignment(company_all_eq)

  pf_file_results_path <- file.path(results_path, portfolio_name_ref_all)
  logger::log_info("Saving results to \"{pf_file_results_path}\".")
  if (!dir.exists(pf_file_results_path)) {
    logger::log_info("Creating results folder: \"{pf_file_results_path}\".")
    dir.create(pf_file_results_path)
  } else {
    logger::log_info("Results folder exists: \"{pf_file_results_path}\".")
  }

  if (data_check(company_all_eq)) {
    company_all_eq_file <- file.path(pf_file_results_path, "Equity_results_company.rds")
    logger::log_info("Saving company equity results to \"{company_all_eq_file}\".")
    saveRDS(company_all_eq, company_all_eq_file)
  } else {
    logger::log_warn("No equity company results found. Skipping saving company results.")
  }

  if (data_check(port_all_eq)) {
    port_all_eq_file <- file.path(pf_file_results_path, "Equity_results_portfolio.rds")
    logger::log_info("Saving portfolio equity results to \"{port_all_eq_file}\".")
    saveRDS(port_all_eq, port_all_eq_file)
  } else {
    logger::log_warn("No equity portfolio results found. Skipping saving portfolio results.")
  }

  if (has_map) {
    if (data_check(map_eq)) {
      saveRDS(map_eq, file.path(pf_file_results_path, "Equity_results_map.rds"))
    } else {
      logger::log_warn("No equity map results found. Skipping saving map results.")
    }
  } else {
    logger::log_warn("No map data available. Skipping map results.")
  }

  logger::log_trace("removing R objects to reduce memory footprint.")
  rm(port_raw_all_eq)
  rm(port_eq)
  rm(port_pw_eq)
  rm(port_own_eq)
  rm(port_all_eq)
  rm(company_pw_eq)
  rm(company_own_eq)
  rm(company_all_eq)
} else {
  logger::log_info("No equity data found. Skipping equity calculations.")
}


# Bonds ------------------------------------------------------------------------

logger::log_info("Creating bond portfolio subset.")
port_raw_all_cb <- create_portfolio_subset(total_portfolio, "Bonds")

if (inherits(port_raw_all_cb, "data.frame") && nrow(port_raw_all_cb) > 0) {
  logger::log_info("Bond data found. Starting bond calculations.")

  map_cb <- NA
  company_all_cb <- NA
  port_all_cb <- NA

  logger::log_info("Calculating weights for bond portfolio.")
  port_cb <- calculate_weights(port_raw_all_cb, "Bonds")

  logger::log_info("Merging ABCD data from database.")
  port_cb <- merge_abcd_from_db(
    portfolio = port_cb,
    portfolio_type = "Bonds",
    db_dir = analysis_inputs_path,
    equity_market_list = equity_market_list,
    scenario_sources_list = scenario_sources_list,
    scenario_geographies_list = scenario_geographies_list,
    sector_list = sector_list,
    id_col = "credit_parent_ar_company_id"
  )

  # Portfolio weight methodology
  logger::log_info("Calculating portfolio weight allocation for bonds.")
  port_pw_cb <- port_weight_allocation(port_cb)

  logger::log_info("Aggregating company data based on portfolio weights.")
  company_pw_cb <- aggregate_company(port_pw_cb)

  logger::log_info("Aggregating portfolio data based on portfolio weights.")
  port_pw_cb <- aggregate_portfolio(company_pw_cb)

  # Create combined outputs
  company_all_cb <- company_pw_cb

  port_all_cb <- port_pw_cb

  if (has_map) {
    if (data_check(company_all_cb)) {
      logger::log_info("Merging in geography data.")
      abcd_raw_cb <- get_abcd_raw("Bonds")
      map_cb <- merge_in_geography(company_all_cb, abcd_raw_cb)
      rm(abcd_raw_cb)

      map_cb <- aggregate_map_data(map_cb)
    } else {
      logger::log_warn("No bond company data found. Skipping map calculations.")
    }
  } else {
    logger::log_info("No map data available. Skipping map calculations.")
  }

  # Technology Share Calculation
  if (nrow(port_all_cb) > 0) {
    logger::log_info("Calculating portfolio technology share for bonds.")
    port_all_cb <- calculate_technology_share(port_all_cb)
  } else {
    logger::log_warn("No bond portfolio data found. Skipping technology share calculations.")
  }

  if (nrow(company_all_cb) > 0) {
    logger::log_info("Calculating company technology share for bonds.")
    company_all_cb <- calculate_technology_share(company_all_cb)
  } else {
    logger::log_warn("No bond company data found. Skipping technology share calculations.")
  }

  # Scenario alignment calculations
  logger::log_info("Calculating scenario alignment for portfolio bond data.")
  port_all_cb <- calculate_scenario_alignment(port_all_cb)

  logger::log_info("Calculating scenario alignment for company bond data.")
  company_all_cb <- calculate_scenario_alignment(company_all_cb)

  pf_file_results_path <- file.path(results_path, portfolio_name_ref_all)
  logger::log_info("Saving results to \"{pf_file_results_path}\".")
  if (!dir.exists(pf_file_results_path)) {
    logger::log_info("Creating results folder: \"{pf_file_results_path}\".")
    dir.create(pf_file_results_path)
  } else {
    logger::log_info("Results folder exists: \"{pf_file_results_path}\".")
  }

  if (data_check(company_all_cb)) {
    company_all_cb_file <- file.path(pf_file_results_path, "Bonds_results_company.rds")
    logger::log_info("Saving company bond results to \"{company_all_cb_file}\".")
    saveRDS(company_all_cb, company_all_cb_file)
  } else {
    logger::log_warn("No bond company results found. Skipping saving company results.")
  }

  if (data_check(port_all_cb)) {
    port_all_cb_file <- file.path(pf_file_results_path, "Bonds_results_portfolio.rds")
    logger::log_info("Saving portfolio bond results to \"{port_all_cb_file}\".")
    saveRDS(port_all_cb, port_all_cb_file)
  } else {
    logger::log_warn("No bond portfolio results found. Skipping saving portfolio results.")
  }

  if (has_map) {
    if (data_check(map_cb)) {
      map_cb_file <- file.path(pf_file_results_path, "Bonds_results_map.rds")
      logger::log_info("Saving bond map results to \"{map_cb_file}\".")
      saveRDS(map_cb, map_cb_file)
    } else {
      logger::log_warn("No bond map results found. Skipping saving map results.")
    }
  } else {
    logger::log_warn("No map data available. Skipping map results.")
  }

  logger::log_trace("removing R objects to reduce memory footprint.")
  rm(port_raw_all_cb)
  rm(port_cb)
  rm(port_pw_cb)
  rm(port_all_cb)
  rm(company_pw_cb)
  rm(company_all_cb)
} else {
  logger::log_info("No bond data found. Skipping bond calculations.")
}

logger::log_trace("removing R objects to reduce memory footprint.")
remove_if_exists(port_raw_all_eq)
remove_if_exists(port_raw_all_cb)
remove_if_exists(ald_scen_eq)
remove_if_exists(ald_scen_cb)
remove_if_exists(company_all_eq)
remove_if_exists(company_all_cb)
remove_if_exists(port_eq)
remove_if_exists(port_cb)
remove_if_exists(company_own_eq)

logger::log_info("web_tool_script_2.R completed.")
