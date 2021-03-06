library(fwPackage, lib.loc = "package")
library(lattice)
library(tikzDevice)

ltheme <- canonical.theme(color = FALSE)     ## in-built B&W theme  
ltheme$strip.background$col <- "transparent" ## change strip bg  
lattice.options(default.theme = ltheme)      ## set as default  

dbc <- dbConnect(dbDriver("SQLite"), dbname = "data/simulations.db")

d <- dbGetQuery(dbc, "
select * from (select ntest, isim, idgp, transform, label, avg(reject) as reject
               from interval 
               where label='size'
                 and ntest >= 10
                 and idgp in (1,2)
                 and transform = 'difference'
                 and scheme='rec'
               group by ntest, isim, idgp, transform, label) s 
join nobs n join coefficients c on n.i=s.isim and c.i=s.idgp")
dbDisconnect(dbc)

d$nlabel <- sprintf("T=%d", d$n)
d$normlabel <- sprintf("c=%d", d$norm)

tikz(file = "floats/mc-dmwsize-rec.tex", width = 6, height = 4.5)
xyplot(reject ~ I(ntest/n) | interaction(nlabel,altlabel,normlabel, sep = ", "),
       data = d,
       ylab = "Rejection Probability", xlab = "$P/T$",
       panel = function(x,y,...) {
         panel.lines(c(0,2/3),c(.1,.1), col = "lightgray")
         panel.xyplot(x,y,...,type = "l")
       },
       layout = c(4,3),
       par.strip.text = list(cex = .55),
       index.cond = list(c(3, 6, 9, 12, 2, 5, 8, 11, 1, 4, 7, 10)))
dev.off()
