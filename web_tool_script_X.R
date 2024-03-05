message("wd: ", getwd())


message("listing files")
list.files("/bound/working_dir/10_Parameter_File/")

message("reading file")
x <- readLines("/bound/working_dir/10_Parameter_File/rmi_pacta_2022q4_general_PortfolioParameters.yml")

cat(x)

message("writing file")
msg <- "Hello, World!"
if (!dir.exists('/bound/working_dir/30_Processed_Inputs/rmi_pacta_2022q4_general')) {
  dir.create('/bound/working_dir/30_Processed_Inputs/rmi_pacta_2022q4_general')
}
writeLines(msg, '/bound/working_dir/30_Processed_Inputs/rmi_pacta_2022q4_general/coveragegraphlegend.json')

message("done")
