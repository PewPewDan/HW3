library(tidyverse)
library(rpart)
library(rpart.plot)
library(rsample) 
library(dplyr)

library(randomForest)
library(lubridate)
library(modelr)

library(gbm)
library(pdp)
library(MASS)

library(readr)
CAhousing <- read_csv("CAhousing.csv")

#creating variables demonstrating averages of statistics per household
CAH <- CAhousing %>%
  mutate(avg_rooms = totalRooms/households, 
         avg_bedrooms = totalBedrooms/households,
         avg_house_pop = population/households) 

#split data
CAH_split = initial_split(CAH)
CAH_train = training(CAH_split)
CAH_test = testing(CAH_split)

CAH_forest = randomForest(medianHouseValue ~ housingMedianAge + medianIncome + 
                          avg_rooms + avg_bedrooms + avg_house_pop + longitude
                          + latitude, data = CAH_train,
                          importance = TRUE)

# shows out-of-bag MSE as a function of the number of trees used
plot(CAH_forest)

#Forest Prediction for price given location
partialPlot(CAH_forest, as.data.frame(CAH_test), longitude, las=1)
partialPlot(CAH_forest, as.data.frame(CAH_test), latitude, las=1)



#Boosting
#Make a build set and a check set to adjust parameters
#Alex has already tuned the parameters, the code for that is commented out
#the final boosted model is CAH_boost3

# CAH_train_split = initial_split(CAH_train)
# CAH_boost_build = training(CAH_train_split)
# CAH_boost_check = testing(CAH_train_split)


# CAH_boost1 = gbm(medianHouseValue ~ housingMedianAge + medianIncome +
#                     avg_rooms + avg_bedrooms + avg_house_pop + longitude
#                     + latitude, data = CAH_boost_build,
#              interaction.depth=11, n.trees=1000, shrinkage=.08)
# 
# CAH_boost2 = gbm(medianHouseValue ~ housingMedianAge + medianIncome +
#                    avg_rooms + avg_bedrooms + avg_house_pop + longitude
#                  + latitude, data = CAH_boost_build,
#                     interaction.depth=14, n.trees=1000, shrinkage=.08)

# rmse(CAH_boost1, CAH_boost_check)
# rmse(CAH_boost2, CAH_boost_check)
# rmse(CAH_boost3, CAH_boost_check)


CAH_boost3 = gbm(medianHouseValue ~ housingMedianAge + medianIncome +
                   avg_rooms + avg_bedrooms + avg_house_pop + longitude
                 + latitude, data = CAH_train,
                    interaction.depth=12, n.trees=1000, shrinkage=.08)

#Plot of predictions for y given location                 
p1 = pdp::partial(CAH_boost3, pred.var = 'longitude', n.trees=1000)
p1
ggplot(p1) + geom_point(mapping=aes(x=longitude, y=yhat))

p2 = pdp::partial(CAH_boost3, pred.var = 'latitude', n.trees=1000)
p2
ggplot(p2) + geom_point(mapping=aes(x=latitude, y=yhat))

CAH_lm = lm(data = CAH_train, medianHouseValue ~ housingMedianAge + medianIncome +
              avg_rooms + avg_bedrooms + avg_house_pop + longitude
            + latitude )
CAH_stepwise = stepAIC(CAH_lm, direction = "both", 
                        trace = FALSE)
summary(CAH_lm)
summary(CAH_stepwise)

#When I ran it the boosted model beat the forest but add other models using 
#stepwise selection and lasso
rmse(CAH_boost3, CAH_test)
rmse(CAH_forest, CAH_test)
rmse(CAH_lm, CAH_test)
