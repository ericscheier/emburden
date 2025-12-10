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
#' Calculates Net Energy Burden with proper aggregation methodology via the
#' Net Energy Return (Nh) framework. For individual households, NEB = EB = S/G.
#' When aggregating across households (with weights), automatically uses the
#' Nh method to avoid 1-5% aggregation errors.
#'
#' @param g Numeric vector of gross income values
#' @param s Numeric vector of energy spending values
#' @importFrom stats weighted.mean
#' @param se Optional numeric vector of effective energy spending (defaults to s)
#' @param weights Optional numeric vector of weights for aggregation (e.g., household counts).
#'   When provided, uses Nh method: `1 / (1 + weighted.mean(nh, weights))`
#' @param aggregate Logical, if TRUE forces aggregation even without weights (uses unweighted mean).
#'   Default FALSE for backwards compatibility.
#'
#' @returns
#' - If `weights = NULL` and `aggregate = FALSE`: Numeric vector of individual NEB values (S/G)
#' - If `weights` provided or `aggregate = TRUE`: Single aggregated NEB value via Nh method
#'
#' @details
#' **Individual Level:** NEB = EB = S/G (mathematically identical)
#'
#' **Aggregation Modes:**
#' 1. **No aggregation** (default): Returns vector of individual NEB values
#'    ```
#'    neb_func(income, spending)  # Returns vector
#'    ```
#'
#' 2. **Weighted aggregation**: Automatically uses Nh method when weights provided
#'    ```
#'    neb_func(income, spending, weights = households)  # Returns single value
#'    ```
#'
#' 3. **Unweighted aggregation**: Use `aggregate = TRUE` for simple mean
#'    ```
#'    neb_func(income, spending, aggregate = TRUE)  # Returns single value
#'    ```
#'
#' **Why Nh Method?** Avoids 1-5% error from naive averaging:
#' - **CORRECT**: `neb_func(g, s, weights = w)` → Uses Nh internally
#' - **WRONG**: `weighted.mean(s/g, w)` → Introduces bias
#'
#' The Nh method: `1 / (1 + weighted.mean(nh, weights))` where `nh = (g-s)/se`
#' uses arithmetic mean instead of harmonic mean, providing computational
#' simplicity and numerical stability.
#'
#' @seealso [ner_func()] for the Net Energy Return (Nh) calculation
#' @seealso [energy_burden_func()] for simple EB without aggregation support
#' @export
#'
#' @examples
#' # Individual household - returns vector
#' neb_func(50000, 3000)  # 0.06
#' neb_func(c(30000, 50000), c(3000, 3500))  # c(0.10, 0.07)
#'
#' # Aggregation with weights - returns single value (CORRECT method)
#' incomes <- c(30000, 50000, 75000)
#' spending <- c(3000, 3500, 4000)
#' households <- c(100, 150, 200)
#' neb_func(incomes, spending, weights = households)
#'
#' # Unweighted aggregation
#' neb_func(incomes, spending, aggregate = TRUE)
#'
#' # Comparison: naive mean (WRONG) vs Nh method (CORRECT)
#' neb_naive <- weighted.mean(spending/incomes, households)  # Biased
#' neb_correct <- neb_func(incomes, spending, weights = households)  # Correct
#' abs(neb_naive - neb_correct) / neb_correct  # ~1-5% error
neb_func <- function(g, s, se = NULL, weights = NULL, aggregate = FALSE) {
  if (is.null(se)) {
    se <- s
  }

  # Individual household calculation (no aggregation) - backwards compatible
  if (is.null(weights) && !aggregate) {
    return(s / g)
  }

  # Aggregation via Nh method (proper methodology)
  nh <- ner_func(g, s, se)

  if (is.null(weights)) {
    # Unweighted aggregation (aggregate = TRUE case)
    nh_mean <- mean(nh, na.rm = TRUE)
  } else {
    # Weighted aggregation (when weights provided)
    nh_mean <- weighted.mean(nh, weights, na.rm = TRUE)
  }

  # Convert aggregated Nh back to NEB
  neb_aggregated <- 1 / (1 + nh_mean)

  return(neb_aggregated)
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
