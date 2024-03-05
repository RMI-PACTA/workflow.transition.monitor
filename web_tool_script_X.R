message("reading file")

list.files("/bound/working_dir/10_Parameter_File/")
x <- readLines("/bound/working_dir/10_Parameter_File/rmi_pacta_2023q4_general_PortfolioParameters.yml")

cat(x)

message("writing file")
msg <- "Hello, World!"
writeLines(msg, '/bound/working_dir/30_Processed_Inputs/rmi_pacta_2022q4_general/coveragegraphlegend.json')

message("done")
