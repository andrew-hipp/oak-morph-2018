## simulate sampling

library(mvtnorm)
library(magrittr)
library(parallel)
Ncores = 14

load('oakData.Rdata')

otm <- oak.tree.means
otm$site <- oak.dat$site[match(row.names(otm), oak.dat$tree)]
charVec <- c("bladeL", "bladeW", "sinusMinL", "sinusNextL",
          "petioleL", "petioleW", "bladeLtoWidestPoint",
          "Area", "Mass",
          "bladeBaseAngle")

genSims <- function(Nsites = 2,
                    Ntrees = 3,
                    Nleaves = 4,
                    Nreps = 5,
                    siteMeans = oak.means,
                    treeMeans = otm,
                    all.dat = oak.dat,
                    chars = charVec,
                    writeDat = TRUE
                    ) {
  # characters to simulate

  # 1. calculate covariance matrices for all data
  Csites <- cov(siteMeans[, chars]) # cov among site means
  Ctrees <- lapply(split(otm[, chars], otm$site), cov) %>%
           Reduce('+', .) / length(unique(otm$site)) # cov among tree means, within sites
  Cleaves <- lapply(split(all.dat[, chars], all.dat$tree), cov) %>%
             Reduce('+', .) / length(unique(all.dat$tree)) # cov among leaves, within trees

  simulationsList <- vector('list')

  ## 2. simulate:
  for(sites in Nsites) {
    simulationsList[[sites]] <- vector('list')
    for(trees in Ntrees) {
      simulationsList[[sites]][[trees]] <- vector('list')
      for(leaves in Nleaves) {
        message(paste('Doing', sites, 'sites of', trees, 'trees, each with', leaves, 'leaves;', Nreps, 'replicates'))
        simulationsList[[sites]][[trees]][[leaves]] <- mclapply(seq(Nreps), function(...) {
          if(exists('leavesSim.frame')) rm(leavesSim.frame)
          siteMeansSim <- rmvnorm(sites, mean = apply(siteMeans[, chars], 2, mean),
                                  sigma = Csites)
          # the next line returns trees on the rows, characters as the columns, with a list, one per site
          treeMeansSim <- lapply(split(siteMeansSim, row(siteMeansSim)),
                                 function(x) rmvnorm(n = trees, mean = x, sigma = Ctrees))
          leavesSim <- lapply(treeMeansSim, function(x) {
                                   lapply(split(x, row(x)), function(y) {
                                     rmvnorm(n = leaves, mean = y, sigma = Cleaves) %>%
                                     as.data.frame
                                     })
                                   })
          for(i in 1:length(leavesSim)) {
            for(j in 1:length(leavesSim[[i]])) {
              leavesSim[[i]][[j]]$site <- i
              leavesSim[[i]][[j]]$tree <- j
              if(!exists('leavesSim.frame')) leavesSim.frame <- leavesSim[[i]][[j]]
              else leavesSim.frame <- rbind(leavesSim.frame, leavesSim[[i]][[j]]) %>% as.data.frame
            } # close j
          } # close i
          names(leavesSim.frame) <- c(chars, 'site', 'tree')
          leavesSim.frame$site <- factor(leavesSim.frame$site)
          leavesSim.frame$tree <- factor(leavesSim.frame$tree)
          leavesSim.frame
        }, mc.cores = Ncores) # close simulationsList
      } # close leaves
    } # close trees
  } # close sites
  attr(simulationsList, 'Nsites') <- Nsites
  attr(simulationsList, 'Ntrees') <- Ntrees
  attr(simulationsList, 'Nleaves') <- Nleaves
  if(writeDat) save(simulationsList, file = format(Sys.time(), 'simsList.%Y-%m-%d.Rdata'))
  return(simulationsList)
  } # close genSims function
