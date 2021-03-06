#Read arguments from command line
args <- commandArgs()
#Fifth argument is species name
name <- args[5]

#Read file 'similarities' 
x <- read.table("similarities")

#Make PNG picture of histogram from values in 'similarities'
png(file="simil.png", width=600, height=600)
hist ((100-x$V1)/100, main = name, xlab = "Sequence divergence [%]")
dev.off()
