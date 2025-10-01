library(jsonlite)
library(dplyr)
library(data.table)

# Function to read JSON file in chunks and process it
read_json_in_chunks <- function(json_file_path, chunk_size = 1000) {
  con <- file(json_file_path, "r")
  on.exit(close(con))
  
  json_data <- list()
  while(TRUE) {
    chunk <- readLines(con, n = chunk_size, warn = FALSE)
    if(length(chunk) == 0) break
    
    json_chunk <- fromJSON(paste(chunk, collapse = ""))
    json_data <- append(json_data, list(json_chunk))
  }
  
  return(rbindlist(json_data, fill = TRUE))
}

# Function to convert $numberLong values to numeric
convert_numberLong <- function(dt) {
  dt[, lapply(.SD, function(col) {
    if (is.list(col) && all(sapply(col, is.list) & sapply(col, function(x) "$numberLong" %in% names(x)))) {
      as.numeric(sapply(col, function(x) x$numberLong))
    } else {
      col
    }
  })]
}

# Specify the path to your JSON file
json_file_path <- "data/usurdb.json"

# Read the JSON file in chunks
json_data <- read_json_in_chunks(json_file_path)

# Convert the JSON data to a data.table
initial_data_table <- as.data.table(json_data)
# Remove json_data to free up memory
rm(json_data)

# Apply the function to the data.table to convert $numberLong values
converted_data_table <- convert_numberLong(initial_data_table)
# Remove initial_data_table to free up memory
rm(initial_data_table)

# Flatten the JSON data if necessary
flattened_data <- flatten(converted_data_table)
final_data_table <- as.data.table(flattened_data)
# Remove converted_data_table and flattened_data to free up memory
rm(converted_data_table, flattened_data)

# Specify the path to the output CSV file
csv_file_path <- "data/usurdb_from_json.csv"

# Write the data.table to a CSV file
fwrite(final_data_table, csv_file_path)
# Remove final_data_table to free up memory
rm(final_data_table)
