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

#' Calculate Net Energy Burden (NEB)
#'
#' Calculates Net Energy Burden as the ratio of energy spending to gross income.
#' **Note**: NEB is mathematically identical to Energy Burden (EB = S/G). The
#' distinction is conceptual - "NEB" emphasizes that proper aggregation methodology
#' should be used via Net Energy Return (Nh).
#'
#' @param g Numeric vector of gross income values
#' @param s Numeric vector of energy spending values
#' @param se Optional numeric vector of effective energy spending (defaults to s)
#'
#' @returns Numeric vector of Net Energy Burden values (identical to energy burden)
#'
#' @details
#' **Mathematical Identity:** At the household level, NEB = EB = S/G.
#'
#' **For aggregation across households:**
#' - **Individual household data**: Use `ner_func()` first, then `weighted.mean(nh)`,
#'   then convert back via `neb = 1/(1+nh_mean)`. This uses arithmetic mean instead
#'   of harmonic mean, providing both computational simplicity and numerical stability.
#' - **Cohort data** (pre-aggregated totals): Can use direct calculation
#'   `sum(spending)/sum(income)` which is equivalent to the Nh method.
#' - **Never use** `weighted.mean(neb)` or `weighted.mean(eb)` - this introduces
#'   1-5% error.
#'
#' **Why "NEB" vs "EB"?** The "Net" terminology connects to the Nh (Net Energy Return)
#' framework and reminds users to use proper aggregation. Mathematically identical,
#' conceptually clarifying.
#'
#' @seealso [ner_func()] for the Net Energy Return calculation used in proper aggregation
#' @seealso [energy_burden_func()] for the mathematically identical calculation
#' @export
#'
#' @examples
#' # Individual household - NEB identical to EB
#' neb_func(50000, 3000)  # 0.06
#' energy_burden_func(50000, 3000)  # 0.06 (same)
#'
#' # For aggregation - use Nh method (individual HH data)
#' incomes <- c(30000, 50000, 75000)
#' spending <- c(3000, 3500, 4000)
#' households <- c(100, 150, 200)
#'
#' # CORRECT: Via Nh (arithmetic mean)
#' nh <- ner_func(incomes, spending)
#' nh_mean <- weighted.mean(nh, households)
#' neb_correct <- 1 / (1 + nh_mean)
#'
#' # WRONG: Direct mean of NEB
#' neb_wrong <- weighted.mean(neb_func(incomes, spending), households)
#'
#' # For cohort data (totals already aggregated)
#' total_income <- c(3000000, 7500000, 15000000)
#' total_spend <- c(300000, 525000, 750000)
#' neb_direct <- sum(total_spend) / sum(total_income)  # Simple and correct
neb_func <- function(g, s, se = NULL) {
  energy_burden_func(g, s, se)
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
#' E_b = 1 / (Nh + 1), or equivalently: Nh = (1/E_b) - 1
#'
#' **Why use Nh for aggregation?**
#'
#' For individual household data, the Nh method enables simple arithmetic weighted
#' mean aggregation:
#' - **Via Nh**: `neb = 1 / (1 + weighted.mean(nh, weights))` (arithmetic mean)
#' - **Direct EB**: `neb = 1 / weighted.mean(1/eb, weights)` (harmonic mean)
#'
#' **Computational advantages of the arithmetic mean approach:**
#' 1. **Simpler to compute** - Uses standard `weighted.mean()` function
#' 2. **More numerically stable** - Avoids division by very small EB values (e.g., 0.01)
#' 3. **More interpretable** - "Average net return per dollar spent on energy"
#' 4. **Prevents errors** - Makes it obvious you can't use arithmetic mean on EB directly
#'
#' For cohort data (pre-aggregated totals), direct calculation `sum(S)/sum(G)`
#' is mathematically equivalent to the Nh method but simpler.
#'
#' The 6% energy burden poverty threshold corresponds to Nh \eqn{\ge} 15.67.
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
