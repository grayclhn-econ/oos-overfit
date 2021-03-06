GenerateOosPair <- function(X.full, Y, ntrain, nreg.null, nreg.alt, b.true, allR = FALSE) {
  new("oos.pair",
      model.null = GenerateOosForecast(X.full, Y, ntrain, nreg.null, b.true, allR),
      model.alt  = GenerateOosForecast(X.full, Y, ntrain, nreg.alt,  b.true, allR),
      f.test = FTestPValue(X.full[, 1:nreg.null, drop = FALSE], 
        X.full[, 1:nreg.alt, drop = FALSE], Y),
      b.true = b.true,
      nobs = length(Y))
}
