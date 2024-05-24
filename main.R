

options(scipen = 999)

source('config.R', encoding = "UTF-8")
# source('../programs/launch_request.R')
source('programs/NR.R')
source('programs/Production.R')
source('programs/CNIV.R')
#source('../historique/Mise ? jour historique.R')

gc()
memory.limit(9e12)

################################################################################
#                              IMPORT INPUT FILES                              #
################################################################################

input_object <- Input(
  date_ref = date_ref,
  date_prediction = date_prediction,
  date_publication = date_publication,
  
  input_directory = input_directory, 
  # astrineo = astrineo_input,
  intro_imput = intro_imput_file, 
  exped_imput = exped_imput_file, 
  intro_ventil = intro_ventil_file, 
  exped_ventil = exped_ventil_file, 
  ER = ER_file,
  ca3 = ca3_file, 

  sample_directory = sample_directory,
  sample = sample_file, 

  msd = msd_file, 
  
  historical_directory = historical_directory,
  use_historical_basis = use_historical_basis,
  save_historical_input = save_historical_input,

  use_gazelec_file = use_gazelec_file,
  add_gazelec_data = add_gazelec_data,
  gazelec = gazelec_file,

  output_directory = output_directory, 
  output_freenas_directory = output_freenas_directory,
  
  pass = pass_file, 
  cniv = cniv_file
)

sample <- import_sample(input_object)
sample_intro <- get_sample_by_flow(input_object, "I")
sample_exped <- get_sample_by_flow(input_object, "E")


delete <- import_delete(input_object)

msd <- import_msd(input_object)


################################################################################
#                            LAUNCH SIMULATIONS                                #
################################################################################

##==============================================================================
## Introduction
##==============================================================================
start=Sys.time()
source('programs/launch_introduction.R')
print(Sys.time()-start)

##==============================================================================
## Expedition
##==============================================================================
start=Sys.time()
source('programs/launch_expedition.R')
print(Sys.time()-start)
################################################################################
#                                  PRODUCTION                                  #
################################################################################

source('programs/launch_production.R')

source('programs/imputations_NATR.R',encoding = 'UTF-8')
source('programs/imputations_transport48Kv2.R',encoding = 'UTF-8')
source('programs/prgm_C3290.R')


################################################################################
#                                  CONTROLE                                    #
################################################################################
source('programs/Controles_imput_PC_yb.R')


################################################################################
#                                       CNIV                                   #
################################################################################

source('programs/launch_cniv.R')
