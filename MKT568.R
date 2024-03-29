#' ---
#' title: "MKT568"
#' author: "Yang Fu"
#' date: "4/24/2019"
#' output: html_document
#' ---
#' 
## ------------------------------------------------------------------------
library(lubridate)
library(dplyr)
library(ggplot2)

#' 
## ------------------------------------------------------------------------
bake = read.csv('BreadBasket_DMS.csv')
head(bake)

#' 
## ------------------------------------------------------------------------
bake$Date = ymd(bake$Date)
bake$Time = hms(bake$Time)
bake$ts = with(bake, as.POSIXct(paste(Date, Time)))
bake$h = hour(bake$Time)
bake$m = month(bake$Date)
bake$y = year(bake$Date)
summary(bake)
bake = subset(bake,Item !='NONE')
head(bake)

#' 
## ------------------------------------------------------------------------
#Transaction Time Series
#monthly transaction: groupby year and month, count number of transactions
bts = bake %>% group_by(y,m) %>% summarise(n_t = length(unique(Transaction)))
#daily transaction: groupby date, count number of transactions
tran_ts = bake %>% group_by(Date) %>% summarise(n_t=length(unique(Transaction)))
ts = ts(tran_ts$n_t)
#daily transaction plot
plot(ts)
#Autocorrelation
acf(ts,lag=70)
#Partial Autocorrelation
pacf(ts,lag=70)

#' 
## ------------------------------------------------------------------------
#Product Transaction
#groupby item, count sum and ratio
bfreq=bake %>% group_by(Item) %>% summarise(n=n(), p=n/nrow(bake)) %>% arrange(desc(n))
#top10
btop = bfreq[1:10,]
ggplot(btop,aes(x = reorder(Item,-n),y=n))+geom_col() +
  labs(x='Items',y='Number of Sales',title='Top 10 Sales by Number')+
  theme(plot.title=element_text(size=20, face="bold", hjust=0.5),
        axis.text.x=element_text(angle=45,hjust=1,size=10),
        axis.text.y=element_text(size=10))+
  labs(title="Top 10 Sales by Number")

#' 
## ------------------------------------------------------------------------
blank_theme <- theme_minimal()+
  theme(
  axis.title.x = element_blank(),
  axis.title.y = element_blank(),
  panel.border = element_blank(),
  panel.grid=element_blank(),
  axis.ticks = element_blank(),
  plot.title=element_text(size=20, face="bold", hjust=0.5)
  )

#' 
## ------------------------------------------------------------------------
library(scales)

ggplot(btop,aes(x="",y=p,fill=reorder(Item,-p)))+geom_bar(width=1, stat="identity")+
  coord_polar("y", start=pi/2)+scale_fill_grey()+  
  blank_theme+
  blank_theme+theme(axis.text.x=element_blank())+
  geom_text(aes(label=percent(p)),position=position_stack(vjust=0.5))+
  labs(x=NULL,y=NULL,fill=NULL,title="Top 10 Sales by %")
#+guides(fill = guide_legend(reverse = TRUE))
#scale_fill_grey() + theme_minimal()
#bar + coord_polar("y")


#' 
#' 
## ------------------------------------------------------------------------
#top10 2016-11 to 2017-03 5 month
#groupby month and item, and count items 
toplist = bfreq$Item[1:10]
btop = bake %>% select(Transaction,Item,h,m,y) %>% 
                filter(Item %in% toplist) %>% filter(m != 10 & m != 4) %>%
                group_by(y,m,Item) %>% summarize(n=n()) %>% arrange(Item, y, m)
#create date as YYYY-MM-01
btop$date <- ymd(paste(btop$y, btop$m,1, sep="/"))

ggplot(btop,aes(x=date,y=n,color=Item))+
  geom_line(lwd=0.8)+
  geom_point()+
  facet_wrap(~Item,ncol=5)+
  labs(x='Month',y='Number of Sales',title='Product Sales by Months')+
  theme(axis.text.x=element_text(angle=90, hjust=1),
        axis.text.y=element_text(size=10))


#' 
#' 
## ------------------------------------------------------------------------
#hour plot function to visualize the average sales each hour by each top product category
hour_plot <- function(x){
  title = as.character(x)
  sdata <- subset(bake,Item ==x)
  avgdata <- sdata %>% group_by(Date,h) %>% summarise(n = n()) %>% group_by(h) %>% summarise(sum_n = mean(n))
  plot(avgdata,type='b',main=title)
}

#filter top 10 items
sdata = subset(bake,Item %in% toplist)
#groupby hour and count and average by day
#only look at 8am-6pm
avgdata = sdata %>% group_by(Date,h,Item) %>% summarise(n = n()) %>% group_by(h,Item) %>% filter(h>=8 & h<=18) %>% summarise(avg_n = mean(n))

ggplot(avgdata,aes(x=h,y=avg_n,color=Item))+
  geom_line(lwd=0.8)+ 
  geom_point() + 
  facet_wrap(~Item, ncol=5)+ 
  labs(x='Hour',y='Average Number of Sales',title='Product Sales by Hour')+
  theme(axis.text.x=element_text(angle=90, hjust=1))

#' 
## ------------------------------------------------------------------------
library(arules)
library(arulesViz)
library(plyr)

#' 
## ------------------------------------------------------------------------
#which item is more likely to be purchased together with another item.
#look at date, transaction, item
bake1 <- bake %>% select(Date,Transaction,Item)
#combine item from the same transaction number
transactionData <- ddply(bake1,c("Transaction","Date"),
                         function(df1)paste(df1$Item,
                                            collapse = ","))
#look at only combined items
titem <- as.data.frame(transactionData$V1)
colnames(titem) <- c("items")
head(titem)
write.csv(titem,"bakeitem.csv", quote = FALSE, row.names = TRUE)

#' 
## ------------------------------------------------------------------------
tdata = read.transactions("bakeitem.csv", format = 'basket', sep=',')
association.rules <- apriori(tdata, parameter = list(supp=0.01, conf=0.5,maxlen=10))
inspect(association.rules)

#' 
## ------------------------------------------------------------------------
plot(association.rules, method="graph")

#' 
#' 
## ------------------------------------------------------------------------
#look at date, transaction, item, w/o coffee
bake2 <- bake %>% select(Date,Transaction,Item) %>% filter(Item != 'Coffee')
#combine item from the same transaction number
transactionData2 <- ddply(bake2,c("Transaction","Date"),
                         function(df1)paste(df1$Item,
                                            collapse = ","))
#look at only combined items
titem2 <- as.data.frame(transactionData2$V1)
colnames(titem2) <- c("items")
head(titem2)
write.csv(titem2,"bakeitemnocoffee.csv", quote = FALSE, row.names = TRUE)

#' 
## ------------------------------------------------------------------------
# adjust support and confidence threshold to get rules
tdatanocoffee = read.transactions("bakeitemnocoffee.csv", format = 'basket', sep=',')
association.rules2 <- apriori(tdatanocoffee, parameter = list(supp=0.001, conf=0.4,maxlen=10))
inspect(association.rules2)

#' 
## ------------------------------------------------------------------------
plot(association.rules2, method="graph")

#' 
#' 
#' 
