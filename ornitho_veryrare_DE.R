rm(list=ls()) 

library(telegram.bot)
library(rvest)
library(xml2)
library(safer)
library(dplyr)

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
url<-"https://www.ornitho.de/index.php?m_id=94&sp_DOffset=1&sp_Cat%5Bnever%5D=1&sp_Cat%5Bveryrare%5D=1&sp_PChoice=all"
#url<-paste0(url, i)
page<-session_jump_to(pgsession, url)
#}

ornithoDErare <- read_html(page)
ornithoDErare
str(ornithoDErare)

decrypt_file("df_obs_old_enc.txt", ascii = TRUE, outfile = "df_obs_old.txt")
df_obs_old<- read.table("df_obs_old.txt") # Alte Art des Tages lesen
df_obs_old <- iconv(df_obs_old, "UTF-8", "WINDOWS-1252")
unlink("df_obs_old.txt")
df_obs_old$anzahl<-as.character(df_obs_old$anzahl)
df_obs_old$art<-as.character(df_obs_old$art)
df_obs_old$ort<-as.character(df_obs_old$ort)

ort <- ornithoDErare %>% 
  rvest::html_nodes('body') %>% 
  xml2::xml_find_all("//div[@class='listSubmenu']") %>% 
  rvest::html_text()

ort
ort<-gsub(".*/ ","",ort)

art <- ornithoDErare %>% 
  rvest::html_nodes('.bodynocolor b') %>% 
  rvest::html_text()

anzahl <- ornithoDErare %>% 
  rvest::html_nodes('.bodynocolor span') %>% 
  rvest::html_text()

df_obs<-data.frame(anzahl,art,ort)
df_obs <- df_obs[order(art),] 
df_obs_update<-dplyr::anti_join(df_obs,df_obs_old)

# send rare observations to telegram
txt_obs<-apply(df_obs,1,paste,collapse=" ")
txt_obs <- paste(txt_obs, collapse = "; ")
txt_obs <- gsub(";", "\n", txt_obs)

txt_obs_old<-apply(df_obs_old,1,paste,collapse=" ")
txt_obs_old <- paste(txt_obs_old, collapse = "; ")
txt_obs_old <- gsub(";", "\n", txt_obs_old)

txt_obs_update<-apply(df_obs_update,1,paste,collapse=" ")
txt_obs_update <- paste(txt_obs_update, collapse = "; ")
txt_obs_update <- gsub(";", "\n", txt_obs_update)

# send message if list is updated
if (txt_obs_old!=txt_obs) {
  if(txt_obs_update!=""){
    bot$sendMessage(chat_id = chat_id, text = txt_obs_update) #, parse_mode = "Markdown"
  }
  #txt_obs <- encrypt_string(txt_obs, ascii = TRUE)
  write.table(df_obs,"df_obs_old.txt") # neue Art des Tages als alte speichern
  unlink("df_obs_old_enc.txt")
  encrypt_file("df_obs_old.txt", ascii = TRUE, outfile = "df_obs_old_enc.txt")
  unlink("df_obs_old.txt")
}
