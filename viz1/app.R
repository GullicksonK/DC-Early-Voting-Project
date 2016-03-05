#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

options(stringsAsFactors = FALSE)

library(shiny)
library(dplyr)
library(RSQLite)
library(lubridate)
library(stringr)
library(readr)
library(magrittr)
library(tidyr)
library(ggplot2)

load("../EarlyVoting.Rdata")

# Define UI for application that draws a histogram
ui <- shinyUI(fluidPage(
   
   # Application title
   titlePanel("Proportion Early Voting"),
   
   # Sidebar with a slider input for number of bins 
   sidebarLayout(
      sidebarPanel(
         
      ),
      
      # Show a plot of the generated distribution
      mainPanel(
         plotOutput("actions_over_time")
      )
   )
))

# Define server logic required to draw a histogram
server <- shinyServer(function(input, output) {
   
   actions_rollup <- reactive({
     filter(election, year(election_day) >= 2010) %>%
       left_join(vote) %>%
       filter(action %in% c("Early", "Voted")) %>%
       group_by(election_day, type, presidential, action) %>%
       summarize(n=n())
   })
   
   proportion_early <- reactive({
     actions_rollup() %>%
       group_by(election_day, type, presidential) %>%
       summarise(early=sum(n[action=="Early"], na.rm=TRUE), 
                   all=sum(n), 
                   prop_early=early/all)
   })
   
   output$actions_over_time <- renderPlot({
     ggplot(proportion_early(), aes(election_day, prop_early, color=type)) +
       geom_point(size=5)
   })
})

# Run the application 
shinyApp(ui = ui, server = server)

