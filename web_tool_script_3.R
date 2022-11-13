library(pacta.portfolio.analysis)
library(cli)
library(readr)
library(jsonlite)
library(config)
library(fs)

# pkgs needed for interactive report
interactice_report_pkgs <- c("bookdown", "ggplot2", "scales", "writexl")
invisible(lapply(interactice_report_pkgs, library, character.only = TRUE, warn.conflicts = FALSE))

cli::cli_h1("web_tool_script_3.R{get_build_version_msg()}")

if (!exists("portfolio_name_ref_all")) { portfolio_name_ref_all <- "TestPortfolio_Input" }
if (!exists("portfolio_root_dir")) { portfolio_root_dir <- "working_dir" }

setup_project()

set_webtool_paths(portfolio_root_dir)

set_portfolio_parameters(file_path = file.path(par_file_path, paste0(portfolio_name_ref_all, "_PortfolioParameters.yml")))

set_project_parameters(file.path(working_location, "parameter_files",paste0("ProjectParameters_", project_code, ".yml")))

analysis_inputs_path <- set_analysis_inputs_path(data_location_ext, dataprep_timestamp)


# quit if there's no relevant PACTA assets -------------------------------------

 total_portfolio_path <- file.path(proc_input_path, portfolio_name_ref_all, "total_portfolio.rds")
 if (file.exists(total_portfolio_path)) {
   total_portfolio <- readRDS(total_portfolio_path)
   quit_if_no_pacta_relevant_data(total_portfolio)
 } else {
   warning("This is weird... the `total_portfolio.rds` file does not exist in the `30_Processed_inputs` directory.")
 }


# fix parameters ---------------------------------------------------------------

if(project_code == "GENERAL"){
  language_select = "EN"
}


# load PACTA results -----------------------------------------------------------

if (file.exists(file.path(proc_input_path, portfolio_name_ref_all, "audit_file.rds"))){
  audit_file <- readRDS(file.path(proc_input_path, portfolio_name_ref_all, "audit_file.rds"))
}else{
  audit_file <- empty_audit_file()
}

# load portfolio overview
if (file.exists(file.path(proc_input_path, portfolio_name_ref_all, "overview_portfolio.rds"))) {
  portfolio_overview <- readRDS(file.path(proc_input_path, portfolio_name_ref_all, "overview_portfolio.rds"))
} else {
  portfolio_overview <- empty_portfolio_overview()
}

if (file.exists(file.path(proc_input_path, portfolio_name_ref_all, "emissions.rds"))){
  emissions <- readRDS(file.path(proc_input_path, portfolio_name_ref_all, "emissions.rds"))
}else{
  emissions <- empty_emissions_results()}

if (file.exists(file.path(proc_input_path, portfolio_name_ref_all, "total_portfolio.rds"))) {
  total_portfolio <- readRDS(file.path(proc_input_path, portfolio_name_ref_all, "total_portfolio.rds"))
} else {
  total_portfolio <- empty_portfolio_results()
}

# load equity portfolio data
if (file.exists(file.path(results_path, portfolio_name_ref_all, "Equity_results_portfolio.rds"))) {
  equity_results_portfolio <- readRDS(file.path(results_path, portfolio_name_ref_all, "Equity_results_portfolio.rds"))
} else {
  equity_results_portfolio <- empty_portfolio_results()
}

# load bonds portfolio data
if (file.exists(file.path(results_path, portfolio_name_ref_all, "Bonds_results_portfolio.rds"))) {
  bonds_results_portfolio <- readRDS(file.path(results_path, portfolio_name_ref_all, "Bonds_results_portfolio.rds"))
} else {
  bonds_results_portfolio <- empty_portfolio_results()
}

# load equity company data
if (file.exists(file.path(results_path, portfolio_name_ref_all, "Equity_results_company.rds"))) {
  equity_results_company <- readRDS(file.path(results_path, portfolio_name_ref_all, "Equity_results_company.rds"))
} else {
  equity_results_company <- empty_company_results()
}

# load bonds company data
if (file.exists(file.path(results_path, portfolio_name_ref_all, "Bonds_results_company.rds"))) {
  bonds_results_company <- readRDS(file.path(results_path, portfolio_name_ref_all, "Bonds_results_company.rds"))
} else {
  bonds_results_company <- empty_company_results()
}

# load equity map data
if (file.exists(file.path(results_path, portfolio_name_ref_all, "Equity_results_map.rds"))) {
  equity_results_map <- readRDS(file.path(results_path, portfolio_name_ref_all, "Equity_results_map.rds"))
} else {
  equity_results_map <- empty_map_results()
}

# load bonds map data
if (file.exists(file.path(results_path, portfolio_name_ref_all, "Bonds_results_map.rds"))) {
  bonds_results_map <- readRDS(file.path(results_path, portfolio_name_ref_all, "Bonds_results_map.rds"))
} else {
  bonds_results_map <- empty_map_results()
}

# load equity tdm data
if (file.exists(file.path(results_path, portfolio_name_ref_all, "Equity_tdm.rds"))) {
  equity_tdm <- readRDS(file.path(results_path, portfolio_name_ref_all, "Equity_tdm.rds"))
} else {
  equity_tdm <- NULL
}

# load bonds tdm data
if (file.exists(file.path(results_path, portfolio_name_ref_all, "Bonds_tdm.rds"))) {
  bonds_tdm <- readRDS(file.path(results_path, portfolio_name_ref_all, "Bonds_tdm.rds"))
} else {
  bonds_tdm <- NULL
}

# load peers results both individual and aggregate
if (file.exists(file.path(analysis_inputs_path, paste0(project_code, "_peers_equity_results_portfolio.rds")))){
  peers_equity_results_portfolio <- readRDS(file.path(analysis_inputs_path, paste0(project_code, "_peers_equity_results_portfolio.rds")))
}else{
  peers_equity_results_portfolio <- empty_portfolio_results()
}

if(file.exists(file.path(analysis_inputs_path, paste0(project_code, "_peers_bonds_results_portfolio.rds")))){
  peers_bonds_results_portfolio <- readRDS(file.path(analysis_inputs_path, paste0(project_code, "_peers_bonds_results_portfolio.rds")))
}else{
  peers_bonds_results_portfolio <- empty_portfolio_results()
}

if (file.exists(file.path(analysis_inputs_path, paste0(project_code, "_peers_equity_results_portfolio_ind.rds")))){
  peers_equity_results_user <- readRDS(file.path(analysis_inputs_path, paste0(project_code, "_peers_equity_results_portfolio_ind.rds")))
}else{
  peers_equity_results_user <- empty_portfolio_results()
}

if(file.exists(file.path(analysis_inputs_path, paste0(project_code, "_peers_bonds_results_portfolio_ind.rds")))){
  peers_bonds_results_user <- readRDS(file.path(analysis_inputs_path, paste0(project_code, "_peers_bonds_results_portfolio_ind.rds")))
}else{
  peers_bonds_results_user <- empty_portfolio_results()
}

indices_equity_results_portfolio <- readRDS(file.path(analysis_inputs_path, "Indices_equity_portfolio.rds"))

indices_bonds_results_portfolio <- readRDS(file.path(analysis_inputs_path, "Indices_bonds_portfolio.rds"))


# create interactive report ----------------------------------------------------

source(file.path(template_path, "create_interactive_report.R"))
source(file.path(template_path, "useful_functions.R"))
source(file.path(template_path, "export_environment_info.R"))

report_name = select_report_template(project_report_name = project_report_name,
                                     language_select = language_select)

template_dir <- file.path(template_path, report_name, "_book")
survey_dir <- file.path(user_results_path, project_code, "survey")
real_estate_dir <- file.path(user_results_path, project_code, "real_estate")
output_dir <- file.path(outputs_path, portfolio_name_ref_all)
dataframe_translations <- readr::read_csv(
  file.path(template_path, "data/translation/dataframe_labels.csv"),
  col_types = cols()
)

header_dictionary <- readr::read_csv(
  file.path(template_path, "data/translation/dataframe_headers.csv"),
  col_types = cols()
)

js_translations <- jsonlite::fromJSON(
  txt = file.path(template_path, "data/translation/js_labels.json")
)

sector_order <- readr::read_csv(
  file.path(template_path, "data","sector_order","sector_order.csv"),
  col_types = cols()
)

# combine config files to send to create_interactive_report()
portfolio_config_path <- file.path(par_file_path, paste0(portfolio_name_ref_all, "_PortfolioParameters.yml"))
project_config_path <- file.path(working_location, "parameter_files", paste0("ProjectParameters_", project_code, ".yml"))

configs <-
  list(
    portfolio_config = config::get(file = portfolio_config_path),
    project_config = config::get(file = project_config_path)
  )

# Needed for testing only
select_scenario_other = scenario_other
twodi_sectors = sector_list
repo_path = template_path
file_name = "template.Rmd"

create_interactive_report(
  repo_path = template_path,
  template_dir = template_dir,
  output_dir = output_dir,
  survey_dir = survey_dir,
  real_estate_dir = real_estate_dir,
  language_select = language_select,
  report_name = report_name,
  project_name = project_name,
  investor_name = investor_name,
  portfolio_name = portfolio_name,
  peer_group = peer_group,
  start_year = start_year,
  select_scenario = select_scenario,
  select_scenario_other = scenario_other,
  portfolio_allocation_method = portfolio_allocation_method,
  scenario_geography = scenario_geography,
  twodi_sectors = sector_list,
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
  equity_tdm = equity_tdm,
  bonds_tdm = bonds_tdm,
  configs = configs
)


# create executive summary -----------------------------------------------------

library(pacta.executive.summary)

survey_dir <- fs::path_abs(file.path(user_results_path, project_code, "survey"))
real_estate_dir <- fs::path_abs(file.path(user_results_path, project_code, "real_estate"))
output_dir <- file.path(outputs_path, portfolio_name_ref_all)
es_dir <- file.path(output_dir, "executive_summary")
if(!dir.exists(es_dir)) {
  dir.create(es_dir, showWarnings = FALSE, recursive = TRUE)
}

exec_summary_template_name <- paste0(project_code, "_", tolower(language_select), "_exec_summary")
exec_summary_template_path <- system.file("extdata", exec_summary_template_name, package = "pacta.executive.summary")

if(dir.exists(exec_summary_template_path)) {
  data_aggregated_filtered <-
    prep_data_executive_summary(
      investor_name = investor_name,
      portfolio_name = portfolio_name,
      peer_group = peer_group,
      start_year = start_year,
      scenario_source = "GECO2021",
      scenario_selected = "1.5C-Unif",
      scenario_geography = "Global",
      equity_market = "GlobalMarket",
      portfolio_allocation_method_equity = "portfolio_weight",
      portfolio_allocation_method_bonds = "portfolio_weight",
      green_techs = c("RenewablesCap", "HydroCap", "NuclearCap", "Hybrid", "Electric", "FuelCell",
                      "Hybrid_HDV", "Electric_HDV", "FuelCell_HDV", "Electric Arc Furnace"),
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
      survey_dir = survey_dir
    )

  render_executive_summary(
    data = data_aggregated_filtered,
    language = language_select,
    output_dir = es_dir,
    exec_summary_dir = exec_summary_template_path,
    survey_dir = survey_dir,
    real_estate_dir = real_estate_dir,
    file_name = "template.Rmd",
    investor_name = investor_name,
    portfolio_name = portfolio_name,
    peer_group = peer_group,
    total_portfolio = total_portfolio,
    scenario_selected = "1.5C-Unif",
    currency_exchange_value = currency_exchange_value
  )

} else {
  # this is required for the online tool to know that the process has been completed.
  invisible(file.copy(file.path("data", "blank_pdf_do_not_delete.pdf"), es_dir))
}
