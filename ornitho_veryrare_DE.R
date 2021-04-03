rm(list=ls()) 

library(telegram.bot)
library(rvest)
library(xml2)

#### Building an R Bot in 3 steps ----
# 1. Creating the Updater object
updater <- Updater(token = Sys.getenv("ORNITHO_BOT"))

bot <- updater[["bot"]]

# Get bot info
print(bot$getMe())

# Get updates
updates <- bot$getUpdates()

# Retrieve your chat id
# Note: you should text the bot before calling `getUpdates`
#chat_id <- updates[[2L]]$from_chat_id() #1 für bot 2 für gruppenchat
chat_id <- Sys.getenv("CHAT_ID")

#### scrap rare observation ----
#Address of the login webpage
login<-"https://www.ornitho.de/index.php?m_id=1180&sp_DOffset=1&sp_PChoice=all&sp_Cat%5Bnever%5D=1&sp_Cat%5Bveryrare%5D=1&sp_FDisplay=SPECIES_PLACE_DATE"

#create a web session with the desired login address
pgsession<-session(login)
pgform<-html_form(pgsession)[[1]]  #in this case the submit is the 1st form
filled_form<-html_form_set(pgform, USERNAME= Sys.getenv("ORNITHO_USER"), PASSWORD= Sys.getenv("ORNITHO_PW"))
session_submit(pgsession, filled_form)

#pre allocate the final results dataframe.
results<-data.frame()  

#loop through all of the pages with the desired info
#for (i in 1:5)
#{
#base address of the pages to extract information from
url<-"https://www.ornitho.de/index.php?m_id=1180&sp_DOffset=1&sp_PChoice=all&sp_Cat%5Bnever%5D=1&sp_Cat%5Bveryrare%5D=1&sp_FDisplay=SPECIES_PLACE_DATE" # nicht original URL
#url<-paste0(url, i)
page<-session_jump_to(pgsession, url)
#}

ornithoDErare <- read_html(page)
ornithoDErare
str(ornithoDErare)

txt_obs_old<-read.table("txt_obs_old.txt") # Alte Art des Tages lesen

txt_obs_old<-as.character(txt_obs_old$x[1]) #Alte Art des Tages zu character

txt_obs <- ornithoDErare %>% 
  rvest::html_nodes('body') %>% 
  xml2::xml_find_all("//div[contains(@class, 'listTop')]") %>% 
  rvest::html_text()

txt_obs

# send rare observations to telegram
txt_obs <- toString(txt_obs)
txt_obs <- gsub(",", "\n", txt_obs)

# send message if list is updated
if (txt_obs_old!=txt_obs) {
  bot$sendMessage(chat_id = chat_id, text = txt_obs, parse_mode = "Markdown")
  write.table(txt_obs,"txt_obs_old.txt") # neue Art des Tages als alte speichern
}

