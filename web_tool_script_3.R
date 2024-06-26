suppressPackageStartupMessages({
  library(pacta.portfolio.utils)
  library(pacta.portfolio.report)
  library(pacta.executive.summary)
  library(cli)
  library(dplyr)
  library(readr)
  library(jsonlite)
  library(fs)
})

cli::cli_h1("web_tool_script_3.R{get_build_version_msg()}")

if (!exists("portfolio_name_ref_all")) {
  portfolio_name_ref_all <- "1234"
}
if (!exists("portfolio_root_dir")) {
  portfolio_root_dir <- "working_dir"
}

setup_project()

set_webtool_paths(portfolio_root_dir)

set_portfolio_parameters(file_path = file.path(par_file_path, paste0(portfolio_name_ref_all, "_PortfolioParameters.yml")))

proj_param_filename <- ifelse(
  project_code == "GENERAL",
  paste0("ProjectParameters_", project_code, "_", port_holdings_date, ".yml"),
  proj_param_filename <- paste0("ProjectParameters_", project_code, ".yml")
)
project_config_path <- file.path(working_location, "parameter_files", proj_param_filename)
set_project_parameters(project_config_path)

analysis_inputs_path <- set_analysis_inputs_path(data_location_ext)

source("R/utils.R")
merge_configs_and_export_environment_info(
  portfolio_config_path = file.path(par_file_path, paste0(portfolio_name_ref_all, "_PortfolioParameters.yml")),
  project_config_path = project_config_path,
  data_manifest_path = file.path(analysis_inputs_path, "manifest.json"),
  dir = log_path,
  filename = "environment_info_webtool3.json"
)


# quit if there's no relevant PACTA assets -------------------------------------

total_portfolio_path <- file.path(proc_input_path, portfolio_name_ref_all, "total_portfolio.rds")
if (file.exists(total_portfolio_path)) {
  total_portfolio <- readRDS(total_portfolio_path)
  quit_if_no_pacta_relevant_data(total_portfolio)
} else {
  warning("This is weird... the `total_portfolio.rds` file does not exist in the `30_Processed_inputs` directory.")
}


# fix parameters ---------------------------------------------------------------

if (project_code == "GENERAL") {
  language_select <- "EN"
}


# load PACTA results -----------------------------------------------------------

readRDS_or_return_alt_data <- function(filepath, alt_return = NULL) {
  if (file.exists(filepath)) {
    return(readRDS(filepath))
  }
  alt_return
}

add_inv_and_port_names_if_needed <- function(data) {
  if (!inherits(data, "data.frame")) {
    return(data)
  }

  if (!"portfolio_name" %in% names(data)) {
    data <- mutate(data, portfolio_name = .env$portfolio_name, .before = everything())
  }

  if (!"investor_name" %in% names(data)) {
    data <- mutate(data, investor_name = .env$investor_name, .before = everything())
  }

  data
}

audit_file <- readRDS_or_return_alt_data(
  filepath = file.path(proc_input_path, portfolio_name_ref_all, "audit_file.rds"),
  alt_return = empty_audit_file()
)
audit_file <- add_inv_and_port_names_if_needed(audit_file)

portfolio_overview <- readRDS_or_return_alt_data(
  filepath = file.path(proc_input_path, portfolio_name_ref_all, "overview_portfolio.rds"),
  alt_return = empty_portfolio_overview()
)
portfolio_overview <- add_inv_and_port_names_if_needed(portfolio_overview)

emissions <- readRDS_or_return_alt_data(
  filepath = file.path(proc_input_path, portfolio_name_ref_all, "emissions.rds"),
  alt_return = empty_emissions_results()
)
emissions <- add_inv_and_port_names_if_needed(emissions)

total_portfolio <- readRDS_or_return_alt_data(
  filepath = file.path(proc_input_path, portfolio_name_ref_all, "total_portfolio.rds"),
  alt_return = empty_portfolio_results()
)
total_portfolio <- add_inv_and_port_names_if_needed(total_portfolio)

equity_results_portfolio <- readRDS_or_return_alt_data(
  filepath = file.path(results_path, portfolio_name_ref_all, "Equity_results_portfolio.rds"),
  alt_return = empty_portfolio_results()
)
equity_results_portfolio <- add_inv_and_port_names_if_needed(equity_results_portfolio)

bonds_results_portfolio <- readRDS_or_return_alt_data(
  filepath = file.path(results_path, portfolio_name_ref_all, "Bonds_results_portfolio.rds"),
  alt_return = empty_portfolio_results()
)
bonds_results_portfolio <- add_inv_and_port_names_if_needed(bonds_results_portfolio)

equity_results_company <- readRDS_or_return_alt_data(
  filepath = file.path(results_path, portfolio_name_ref_all, "Equity_results_company.rds"),
  alt_return = empty_company_results()
)
equity_results_company <- add_inv_and_port_names_if_needed(equity_results_company)

bonds_results_company <- readRDS_or_return_alt_data(
  filepath = file.path(results_path, portfolio_name_ref_all, "Bonds_results_company.rds"),
  alt_return = empty_company_results()
)
bonds_results_company <- add_inv_and_port_names_if_needed(bonds_results_company)

equity_results_map <- readRDS_or_return_alt_data(
  filepath = file.path(results_path, portfolio_name_ref_all, "Equity_results_map.rds"),
  alt_return = empty_map_results()
)
equity_results_map <- add_inv_and_port_names_if_needed(equity_results_map)

bonds_results_map <- readRDS_or_return_alt_data(
  filepath = file.path(results_path, portfolio_name_ref_all, "Bonds_results_map.rds"),
  alt_return = empty_map_results()
)
bonds_results_map <- add_inv_and_port_names_if_needed(bonds_results_map)

peers_equity_results_portfolio <- readRDS_or_return_alt_data(
  filepath = file.path(analysis_inputs_path, paste0(project_code, "_peers_equity_results_portfolio.rds")),
  alt_return = empty_portfolio_results()
)

peers_bonds_results_portfolio <- readRDS_or_return_alt_data(
  filepath = file.path(analysis_inputs_path, paste0(project_code, "_peers_bonds_results_portfolio.rds")),
  alt_return = empty_portfolio_results()
)

peers_equity_results_user <- readRDS_or_return_alt_data(
  filepath = file.path(analysis_inputs_path, paste0(project_code, "_peers_equity_results_portfolio_ind.rds")),
  alt_return = empty_portfolio_results()
)

peers_bonds_results_user <- readRDS_or_return_alt_data(
  filepath = file.path(analysis_inputs_path, paste0(project_code, "_peers_bonds_results_portfolio_ind.rds")),
  alt_return = empty_portfolio_results()
)

indices_equity_results_portfolio <- readRDS(file.path(analysis_inputs_path, "Indices_equity_results_portfolio.rds"))

indices_bonds_results_portfolio <- readRDS(file.path(analysis_inputs_path, "Indices_bonds_results_portfolio.rds"))


# check for indices ------------------------------------------------------------

if (nrow(indices_equity_results_portfolio) == 1L && all(is.na(indices_equity_results_portfolio))) {
  cli::cli_alert_danger("Since the benchmark equity data is empty, some plots may not work as expected.")
}

if (nrow(indices_bonds_results_portfolio) == 1L && all(is.na(indices_bonds_results_portfolio))) {
  cli::cli_alert_danger("Since the benchmark bonds data is empty, some plots may not work as expected.")
}


# check for peer results -------------------------------------------------------

if (project_report_name != "general") {
  if (nrow(peers_equity_results_user) == 1L && all(is.na(peers_equity_results_user))) {
    cli::cli_alert_danger("Since this is not a \"GENERAL\" report, it's probably necessary to have peer results, but the peer results equity user data is empty.")
  }

  if (nrow(peers_bonds_results_user) == 1L && all(is.na(peers_bonds_results_user))) {
    cli::cli_alert_danger("Since this is not a \"GENERAL\" report, it's probably necessary to have peer results, but the peer results bonds user data is empty.")
  }

  if (nrow(peers_equity_results_portfolio) == 1L && all(is.na(peers_equity_results_portfolio))) {
    cli::cli_alert_danger("Since this is not a \"GENERAL\" report, it's probably necessary to have peer results, but the peer results equity portfolio data is empty.")
  }

  if (nrow(peers_bonds_results_portfolio) == 1L && all(is.na(peers_bonds_results_portfolio))) {
    cli::cli_alert_danger("Since this is not a \"GENERAL\" report, it's probably necessary to have peer results, but the peer results bonds portfolio data is empty.")
  }
}


# check scenario sources -------------------------------------------------------

if (!all(na.omit(unique(equity_results_portfolio$scenario_source)) %in% scenario_sources_list)) {
  cli::cli_alert_danger("The equity results data contain scenario sources that are not specified in the config. This may lead to unexpected behavior or errors in some plots.")
}

if (!all(na.omit(unique(bonds_results_portfolio$scenario_source)) %in% scenario_sources_list)) {
  cli::cli_alert_danger("The bonds results data contain scenario sources that are not specified in the config. This may lead to unexpected behavior or errors in some plots.")
}

if (!all(na.omit(unique(indices_equity_results_portfolio$scenario_source)) %in% scenario_sources_list)) {
  cli::cli_alert_danger("The benchmark equity results data contain scenario sources that are not specified in the config. This may lead to unexpected behavior or errors in some plots.")
}

if (!all(na.omit(unique(indices_bonds_results_portfolio$scenario_source)) %in% scenario_sources_list)) {
  cli::cli_alert_danger("The benchmark bonds results data contain scenario sources that are not specified in the config. This may lead to unexpected behavior or errors in some plots.")
}

if (project_report_name != "general") {
  if (!all(na.omit(unique(peers_equity_results_user$scenario_source)) %in% scenario_sources_list)) {
    cli::cli_alert_danger("The peers equity user results data contain scenario sources that are not specified in the config. This may lead to unexpected behavior or errors in some plots.")
  }

  if (!all(na.omit(unique(peers_bonds_results_user$scenario_source)) %in% scenario_sources_list)) {
    cli::cli_alert_danger("The peers bonds user results data contain scenario sources that are not specified in the config. This may lead to unexpected behavior or errors in some plots.")
  }

  if (!all(na.omit(unique(peers_equity_results_portfolio$scenario_source)) %in% scenario_sources_list)) {
    cli::cli_alert_danger("The peers equity portfolio results data contain scenario sources that are not specified in the config. This may lead to unexpected behavior or errors in some plots.")
  }

  if (!all(na.omit(unique(peers_bonds_results_portfolio$scenario_source)) %in% scenario_sources_list)) {
    cli::cli_alert_danger("The peers bonds portfolio results data contain scenario sources that are not specified in the config. This may lead to unexpected behavior or errors in some plots.")
  }
}


# check scenarios --------------------------------------------------------------

default_scenarios <- sub("^[^_]*_", "", c(select_scenario, scenario_other))

if (!all(default_scenarios %in% equity_results_portfolio$scenario)) {
  cli::cli_alert_danger("The default scenario selections do not exist in the equity results. This may lead to unexpected behavior or errors in some plots.")
}

if (!all(default_scenarios %in% bonds_results_portfolio$scenario)) {
  cli::cli_alert_danger("The default scenario selections do not exist in the bonds results. This may lead to unexpected behavior or errors in some plots.")
}

if (!all(default_scenarios %in% indices_equity_results_portfolio$scenario)) {
  cli::cli_alert_danger("The default scenario selections do not exist in the benchmark equity results. This may lead to unexpected behavior or errors in some plots.")
}

if (!all(default_scenarios %in% indices_bonds_results_portfolio$scenario)) {
  cli::cli_alert_danger("The default scenario selections do not exist in the benchmark bonds results. This may lead to unexpected behavior or errors in some plots.")
}

if (project_report_name != "general") {
  if (!all(default_scenarios %in% peers_equity_results_user$scenario)) {
    cli::cli_alert_danger("The default scenario selections do not exist in the peers equity user results. This may lead to unexpected behavior or errors in some plots.")
  }

  if (!all(default_scenarios %in% peers_bonds_results_user$scenario)) {
    cli::cli_alert_danger("The default scenario selections do not exist in the peers bond user results. This may lead to unexpected behavior or errors in some plots.")
  }

  if (!all(default_scenarios %in% peers_equity_results_portfolio$scenario)) {
    cli::cli_alert_danger("The default scenario selections do not exist in the peers equity portfolio results. This may lead to unexpected behavior or errors in some plots.")
  }

  if (!all(default_scenarios %in% peers_bonds_results_portfolio$scenario)) {
    cli::cli_alert_danger("The default scenario selections do not exist in the peers bond portfolio results. This may lead to unexpected behavior or errors in some plots.")
  }
}


# create interactive report ----------------------------------------------------

survey_dir <- file.path(user_results_path, project_code, "survey")
real_estate_dir <- file.path(user_results_path, project_code, "real_estate")
output_dir <- file.path(outputs_path, portfolio_name_ref_all)
dataframe_translations <- readr::read_csv(
  system.file("extdata/translation/dataframe_labels.csv", package = "pacta.portfolio.report"),
  col_types = cols()
)

header_dictionary <- readr::read_csv(
  system.file("extdata/translation/dataframe_headers.csv", package = "pacta.portfolio.report"),
  col_types = cols()
)

js_translations <- jsonlite::fromJSON(
  txt = system.file("extdata/translation/js_labels.json", package = "pacta.portfolio.report")
)

sector_order <- readr::read_csv(
  system.file("extdata/sector_order/sector_order.csv", package = "pacta.portfolio.report"),
  col_types = cols()
)

# combine config files to send to create_interactive_report()
portfolio_config_path <- file.path(par_file_path, paste0(portfolio_name_ref_all, "_PortfolioParameters.yml"))

pacta_data_public_manifest <-
  list(
    creation_time_date = jsonlite::read_json(file.path(analysis_inputs_path, "manifest.json"))$creation_time_date,
    outputs_manifest = jsonlite::read_json(file.path(analysis_inputs_path, "manifest.json"))$outputs_manifest
  )

configs <-
  list(
    portfolio_config = config::get(file = portfolio_config_path),
    project_config = config::get(file = project_config_path),
    pacta_data_public_manifest = pacta_data_public_manifest
  )

# workaround a bug in {config} v0.3.2 that only adds "config" class to objects it creates
class(configs$portfolio_config) <- c(class(configs$portfolio_config), "list")
class(configs$project_config) <- c(class(configs$project_config), "list")

template_dir_name <- paste(tolower(project_report_name), tolower(language_select), "template", sep = "_")
template_dir <- file.path(template_path, template_dir_name)

select_scenario_other <- scenario_other
pacta_sectors <- sector_list

create_interactive_report(
  template_dir = template_dir,
  output_dir = output_dir,
  survey_dir = survey_dir,
  real_estate_dir = real_estate_dir,
  language_select = language_select,
  investor_name = investor_name,
  portfolio_name = portfolio_name,
  peer_group = peer_group,
  start_year = start_year,
  select_scenario = select_scenario,
  select_scenario_other = select_scenario_other,
  portfolio_allocation_method = portfolio_allocation_method,
  scenario_geography = scenario_geography,
  pacta_sectors = pacta_sectors,
  green_techs = green_techs,
  tech_roadmap_sectors = tech_roadmap_sectors,
  pacta_sectors_not_analysed = pacta_sectors_not_analysed,
  audit_file = audit_file,
  emissions = emissions,
  portfolio_overview = portfolio_overview,
  equity_results_portfolio = equity_results_portfolio,
  bonds_results_portfolio = bonds_results_portfolio,
  equity_results_company = equity_results_company,
  bonds_results_company = bonds_results_company,
  equity_results_map = equity_results_map,
  bonds_results_map = bonds_results_map,
  indices_equity_results_portfolio = indices_equity_results_portfolio,
  indices_bonds_results_portfolio = indices_bonds_results_portfolio,
  peers_equity_results_portfolio = peers_equity_results_portfolio,
  peers_bonds_results_portfolio = peers_bonds_results_portfolio,
  peers_equity_results_user = peers_equity_results_user,
  peers_bonds_results_user = peers_bonds_results_user,
  dataframe_translations = dataframe_translations,
  js_translations = js_translations,
  display_currency = display_currency,
  currency_exchange_value = currency_exchange_value,
  header_dictionary = header_dictionary,
  sector_order = sector_order,
  configs = configs
)


# create executive summary -----------------------------------------------------

survey_dir <- fs::path_abs(file.path(user_results_path, project_code, "survey"))
score_card_dir <- fs::path_abs(file.path(user_results_path, project_code, "score_card"))
analysis_inputs_dir <- fs::path_abs(file.path(analysis_inputs_path))
output_dir <- file.path(outputs_path, portfolio_name_ref_all)
es_dir <- file.path(output_dir, "executive_summary")
if (!dir.exists(es_dir)) {
  dir.create(es_dir, showWarnings = FALSE, recursive = TRUE)
}

exec_summary_template_name <- paste0(project_code, "_", tolower(language_select), "_exec_summary")
exec_summary_builtin_template_path <- system.file("extdata", exec_summary_template_name, package = "pacta.executive.summary")
invisible(file.copy(exec_summary_builtin_template_path, output_dir, recursive = TRUE, copy.mode = FALSE))
exec_summary_template_path <- file.path(output_dir, exec_summary_template_name)

if (dir.exists(exec_summary_template_path) && (peer_group %in% c("assetmanager", "bank", "insurance", "pensionfund"))) {
  data_aggregated_filtered <-
    prep_data_executive_summary(
      investor_name = investor_name,
      portfolio_name = portfolio_name,
      peer_group = peer_group,
      start_year = start_year,
      scenario_source = "WEO2023",
      scenario_selected = "NZE_2050",
      scenario_geography = "Global",
      equity_market = "GlobalMarket",
      portfolio_allocation_method_equity = "portfolio_weight",
      portfolio_allocation_method_bonds = "portfolio_weight",
      green_techs = c(
        "RenewablesCap",
        "HydroCap",
        "NuclearCap",
        "Hybrid",
        "Electric",
        "FuelCell",
        "Hybrid_HDV",
        "Electric_HDV",
        "FuelCell_HDV",
        "Electric Arc Furnace"
      ),
      equity_results_portfolio = equity_results_portfolio,
      bonds_results_portfolio = bonds_results_portfolio,
      peers_equity_results_aggregated = peers_equity_results_portfolio,
      peers_bonds_results_aggregated = peers_bonds_results_portfolio,
      peers_equity_results_individual = peers_equity_results_user,
      peers_bonds_results_individual = peers_bonds_results_user,
      indices_equity_results_portfolio = indices_equity_results_portfolio,
      indices_bonds_results_portfolio = indices_bonds_results_portfolio,
      audit_file = audit_file,
      emissions_portfolio = emissions,
      index_dir = analysis_inputs_path
    )

  render_executive_summary(
    data = data_aggregated_filtered,
    language = language_select,
    output_dir = es_dir,
    exec_summary_dir = exec_summary_template_path,
    survey_dir = survey_dir,
    score_card_dir = score_card_dir,
    analysis_inputs_dir = analysis_inputs_dir,
    file_name = "template.Rmd",
    investor_name = investor_name,
    portfolio_name = portfolio_name,
    peer_group = peer_group,
    total_portfolio = total_portfolio,
    scenario_source = "WEO2023",
    scenario_selected = "NZE_2050",
    currency_exchange_value = currency_exchange_value,
    log_dir = log_path
  )
} else {
  # this is required for the online tool to know that the process has been completed.
  invisible(file.copy(blank_pdf(), es_dir))
}
