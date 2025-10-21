#' Calculate Energy Burden
#'
#' Calculates the energy burden as the ratio of energy spending to gross income.
#' Energy burden is defined as E_b = S/G, where S is energy spending and G is
#' gross income.
#'
#' @param g Numeric vector of gross income values
#' @param s Numeric vector of energy spending values
#' @param se Optional numeric vector of effective energy spending (defaults to s)
#'
#' @returns Numeric vector of energy burden values (ratio of spending to income)
#'
#' @export
#'
#' @examples
#' # Calculate energy burden for households
#' gross_income <- c(50000, 75000, 100000)
#' energy_spending <- c(3000, 3500, 4000)
#' energy_burden_func(gross_income, energy_spending)
energy_burden_func <- function(g, s, se = NULL) {
  if (is.null(se)) {
    se <- s
  }
  s / g
}

#' Calculate Energy Return on Investment (EROI)
#'
#' Calculates the Energy Return on Investment as the ratio of gross income to
#' effective energy spending. EROI = G/Se.
#'
#' @param g Numeric vector of gross income values
#' @param s Numeric vector of energy spending values
#' @param se Optional numeric vector of effective energy spending (defaults to s)
#'
#' @returns Numeric vector of EROI values
#'
#' @export
#'
#' @examples
#' # Calculate EROI for households
#' eroi_func(50000, 3000)
eroi_func <- function(g, s, se = NULL) {
  if (is.null(se)) {
    se <- s
  }
  g / se
}

#' Calculate Net Energy Return (Nh)
#'
#' Calculates the Net Energy Return using the formula Nh = (G - S) / Se,
#' where G is gross income, S is energy spending, and Se is effective energy
#' spending. This metric is the preferred aggregation variable as it properly
#' accounts for harmonic mean behavior when aggregating across households.
#'
#' @param g Numeric vector of gross income values
#' @param s Numeric vector of energy spending values
#' @param se Optional numeric vector of effective energy spending (defaults to s)
#'
#' @returns Numeric vector of Net Energy Return (Nh) values
#'
#' @details
#' The Net Energy Return is mathematically related to energy burden by:
#' E_b = 1 / (Nh + 1)
#'
#' The 6% energy burden poverty threshold corresponds to Nh ≤ 15.67.
#'
#' @export
#'
#' @examples
#' # Calculate Net Energy Return
#' gross_income <- 50000
#' energy_spending <- 3000
#' nh <- ner_func(gross_income, energy_spending)
#'
#' # Convert back to energy burden
#' energy_burden <- 1 / (nh + 1)
ner_func <- function(g, s, se = NULL) {
  if (is.null(se)) {
    se <- s
  }
  (g - s) / se
}

#' Calculate Disposable Energy-Adjusted Resources (DEAR)
#'
#' Calculates DEAR as the ratio of net income after energy spending to
#' gross income. DEAR = (G - S) / G.
#'
#' @param g Numeric vector of gross income values
#' @param s Numeric vector of energy spending values
#' @param se Optional numeric vector of effective energy spending (defaults to s)
#'
#' @returns Numeric vector of DEAR values (ratio of disposable income to gross income)
#'
#' @export
#'
#' @examples
#' # Calculate DEAR
#' dear_func(50000, 3000)
dear_func <- function(g, s, se = NULL) {
  if (is.null(se)) {
    se <- s
  }
  (g - s) / g
}
