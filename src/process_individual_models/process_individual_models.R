## countries_to_keep <- c("Algeria", "Austria", "Belgium", "Brazil", "Canada", "China",
## "Colombia", "Czechia", "Denmark", "Dominican_Republic", "Ecuador",
## "Egypt", "France", "Germany", "India", "Indonesia", "Iran", "Ireland",
## "Israel", "Italy", "Mexico", "Morocco", "Netherlands", "Peru",
## "Philippines", "Poland", "Portugal", "Romania", "Russia", "South_Korea",
## "Spain", "Sweden", "Switzerland", "Turkey", "United_Kingdom",
## "United_States_of_America")

output_files <- list(
  "DeCa_Std_results_week_end_2020-03-08.rds",
  "DeCa_Std_results_week_end_2020-03-15.rds",
  "DeCa_Std_results_week_end_2020-03-22.rds",
  "DeCa_Std_results_week_end_2020-03-29.rds",
  "DeCa_Std_results_week_end_2020-04-05.rds",
  "DeCa_Std_results_week_end_2020-04-12.rds",
  "RtI0_Std_results_week_end_2020-03-08.rds",
  "RtI0_Std_results_week_end_2020-03-15.rds",
  "RtI0_Std_results_week_end_2020-03-22.rds",
  "RtI0_Std_results_week_end_2020-03-29.rds",
  "RtI0_Std_results_week_end_2020-04-05.rds",
  "RtI0_Std_results_week_end_2020-04-12.rds",
  "sbkp_Std_results_week_end_2020-03-08.rds",
  "sbkp_Std_results_week_end_2020-03-15.rds",
  "sbkp_Std_results_week_end_2020-03-22.rds",
  "sbkp_Std_results_week_end_2020-03-29.rds",
  "sbkp_Std_results_week_end_2020-04-05.rds",
  "sbkp_Std_results_week_end_2020-04-12.rds",
  "sbsm_Std_results_week_end_2020-04-12.rds"
)

names(output_files) <- gsub(
  pattern = ".rds", replacement = "", x = output_files
)

model_outputs <- purrr::map(
  output_files,
  ~ readRDS(paste0("model_outputs/", .))
  )

## Filter model outputs from DeCa models to reflect the new
## threshold. Needed to be done only once.
## outdated <- output_files <- list(
##   "DeCa_Std_results_week_end_2020-03-08",
##   "DeCa_Std_results_week_end_2020-03-15",
##   "DeCa_Std_results_week_end_2020-03-22",
##   "DeCa_Std_results_week_end_2020-03-29",
##   "DeCa_Std_results_week_end_2020-04-05"
##   )

## purrr::iwalk(
##   model_outputs,
##   function(x, outfile) {

##     ##countries <- names(model_outputs[[right]][["Predictions"]])
##     ##message(countries)
##     idx <- which(
##       names(x[["Predictions"]]) %in% countries_to_keep
##     )
##     message("Keeping ", paste0(idx, collapse = " "))
##     x[["Predictions"]] <- x[["Predictions"]][idx]
##     x[["Country"]] <- countries_to_keep[idx]
##     readr::write_rds(x = x, path = glue::glue("model_outputs/{outfile}.rds"))
##   }
## )

model_input <- readRDS("model_input.rds")

daily_predictions_qntls <- purrr::map_dfr(
  model_outputs,
  function(x) {
    pred <- x[["Predictions"]]
    purrr::map_dfr(
      pred, extract_predictions_qntls,
      .id = "country"
    )
  }, .id = "model"
)

readr::write_rds(
    x = daily_predictions_qntls,
    path = "daily_predictions_qntls.rds"
)


##purrr::walk2(model_predictions_qntls, outfiles, ~ readr::write_rds(.x, .y))

weekly_predictions_qntls <- purrr::map_dfr(
  model_outputs,
  function(x) {
    pred <- x[["Predictions"]]
    purrr::imap_dfr(pred, function(y, country) {
      dates <- as.Date(colnames(y[[1]]))
      obs_deaths <- model_input[["D_active_transmission"]][c("dates", country)]
      ## We now want deaths observed in the week preceding the one
      ## for which we are forecasting.
      dates_prev_week <- dates - 7
      message("Dates of previous week")
      message(paste(dates_prev_week, collapse = ""))
      obs_deaths <- obs_deaths[obs_deaths$dates %in% dates_prev_week, ]
      if (nrow(obs_deaths) == 0) {
        message(
          "No observations for dates ", dates, " in ", country
        )
        obs_deaths <- NA
      } else {
        obs_deaths <- sum(obs_deaths[[country]])
      }

      weekly_df <- daily_to_weekly(y)

      weekly_df$observed <- obs_deaths
      weekly_df
    }, .id = "country")
  },
  .id = "model"
)

readr::write_rds(
    x = weekly_predictions_qntls,
    path = "weekly_predictions_qntls.rds"
)


model_rt_qntls <- purrr::map_dfr(
  model_outputs,
  function(x) {
    pred <- x[["R_last"]]
    purrr::map_dfr(pred, function(y) {
      names(y) <- c("si_1", "si_2")
      out <- purrr::map_dfr(
        y,
        function(y_si) {
          out2 <- quantile(
            y_si,
            prob = c(0.025, 0.1, 0.25, 0.5, 0.75, 0.9, 0.975)
          )
          out2 <- as.data.frame(out2)
          out2 <- tibble::rownames_to_column(
            out2,
            var = "quantile"
          )
          out2
        },
        .id = "si"
      )
    }, .id = "country")
  }, .id = "model"
)

readr::write_rds(
    x = model_rt_qntls,
    path = "model_rt_qntls.rds"
)


model_rt_samples <- purrr::map_dfr(
  model_outputs,
  function(x) {
    rt <- x[["R_last"]]
    purrr::map_dfr(
      rt,
      function(cntry) {
        data.frame(
          si_1 = cntry[[1]],
          si_2 = cntry[[2]]
        )
     }, .id = "country"
  )
  }, .id = "model"
)

readr::write_rds(
    x = model_rt_samples,
    path = "model_rt_samples.rds"
)


######## Re-organising Sam's Model Outputs #########################
## x <- readr::read_rds("model_outputs/SBSM_Output_shortterm_12_04_2020.rds")
## input <- readr::read_rds("~/GitWorkArea/covid19-forecasts-orderly/archive/prepare_ecdc_data/20200413-113115-b1f97002/latest_model_input.rds")
## country <- purrr::map(x, ~.[["country"]])
## predictions <- purrr::map(x, ~ .[["deaths"]])
## predictions <- purrr::map(predictions, ~ .[, seq(to = ncol(.), length.out = 7, by = 1)])
## dates_predicted <- purrr::map(x, ~ tail(.[["time"]], 7))
## predictions_named <- purrr::map2(
##   predictions,
##   dates_predicted,
##   function(pred, dates) {
##     pred <- data.frame(pred)
##     pred <- pred[rep(seq_len(nrow(pred)), each = 5), ]
##     colnames(pred) <- dates
##     pred
##   }
##   )

## rlast <- purrr::map(x, ~ as.vector(tail(.[["rt"]] , 1)))
## rlast <- purrr::map(rlast, ~ rep(. , each = 5))
## names(rlast) <- country

## rlast_list <- purrr::map(rlast, ~ list(., .))
## pred_list  <- purrr::map(predictions_named, ~ list(., .))
## names(pred_list) <- country
## keep <- which(! country %in% c("Greece", "Norway"))
## out <- list(
##   Country = country[keep],
##   R_last = rlast_list[keep],
##   Predictions = pred_list[keep],
##   D_active_transmission = input$D_active_transmission,
##   I_active_transmission = input$I_active_transmission

## )

## readr::write_rds(out, "model_outputs/sbsm_Std_results_week_end_2020-04-12.rds")
