#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) {
  stop("Usage: Rscript count_sites.R <sites.txt> <site_counts.csv>", call. = FALSE)
}

input_file <- args[1]
output_file <- args[2]

if (!file.exists(input_file)) {
  stop(paste("Input file not found:", input_file), call. = FALSE)
}

if (file.info(input_file)$size == 0) {
  result <- data.frame(site = character(), Freq = integer())
} else {
  data <- read.table(
    input_file,
    header = FALSE,
    sep = "",
    col.names = c("chrom", "position"),
    colClasses = c("character", "integer"),
    comment.char = "",
    quote = ""
  )
  site <- paste0(data$chrom, ":", data$position)
  counts <- table(site)
  result <- data.frame(site = names(counts), Freq = as.integer(counts), row.names = NULL)
}

write.csv(result, output_file, row.names = FALSE, quote = TRUE)
cat(sprintf("Site counting completed: %d unique sites written to %s\n", nrow(result), output_file))
