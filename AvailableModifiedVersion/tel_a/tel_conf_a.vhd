--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions

--===============================================================================================
-- fichier de configuration telescope - A -
--===============================================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;

package telescope_conf is

constant build_a : boolean := true;
--constant build_b : boolean := false;

constant YEAR :   integer := 2019;
constant MONTH:   integer := 09;
constant DAY:     integer := 19;
constant VARIANT: integer := 1;

-- tyyyy_mmm_mddd_ddvv

constant VERSION_VHDL : std_logic_vector (15 downto 0) :=
  "0" &
  conv_std_logic_vector(YEAR-2012, 4) &
  conv_std_logic_vector(MONTH, 4) &
  conv_std_logic_vector(DAY, 5) &
  conv_std_logic_vector(VARIANT,2);

constant chip_teles       : boolean := false;
constant chip_flink       : boolean := false;
constant chip_trigger     : boolean := false;
constant chip_read_engine : boolean := false;
constant chip_ener        : boolean := false;
constant chip_waver       : boolean := false;
constant chip_reader      : boolean := false; -- instanciate chipscope in reader
constant chip_csi         : boolean := false;

end telescope_conf;

-- les commentaires concernant les modifications communes aux deux télescopes figurent
-- exclusivement dans le fichier tel_conf_a.vhd

-- 21-09-2012/0 modifié leds de trigger:
--   led verte = signale une requête locale (lt)
--   led rouge = signale une validation

-- 24-09-2012/0 modifié les paramètres par défaut:
-- DEFAULT_PRETRIG <- 512 et DEFAULT_DEPTH <- 1024

-- 26-09-2012/0 modifié le comportement de readEngine pour tenir compte des handshake venant de
--   la blockCard nb. il faudra verifier les latences des données en provenance des voies
--   (réponse au signal throttle)
-- 2-10-2012 renommé le fichier telescope_conf.vhd --> tel_conf_a.vhd
--   ajouté pulldown sur 3 entrées connecteur
-- 3-10-2012/2 dans waver, ajouté plancher de la limite inférieure de longueur de signal
--   (on ne peut pas mettre moins de 4)
-- 4-10-2012/0 corrigé bug de lecture de registre dans blockTrig
-- 5-10-2012/0 ajouté relecture des registres de source et de mode de trigger
-- 9-10-2012/0 mis à jour paramétrage et valeurs par défaut
-- 10-10-2012/0 glt provient par défaut du connecteur, modifié leds par défaut (lt, val,
--                                                                               couleurs A et B)
-- 11-10-2012/0 modifié le paramétrage pour augmenter la taille du MEB lent à 8192
--              (pour pouvoir observer le bruit à basse fréquence des alimentations block)
-- 11-10-2012/1 passé lwait de A en logique négative drain ouvert
-- 15-10-2012/0 modifié le chargement parallèle des données LMK (état zéro au repos et
--                                                      un coup de LEuWire à la fin de chaque mot)
-- 17-10-2012 retour à des MEB QH1,Q2,Q3 de 4k. Il n'y a pas de place actuellement dans l'espace
--   d'adressage pour 8k. Nouvelle version de micro_wire (modif mineure des signaux LE)
-- 23-10-2012 mis en place la gestion définitive du MEB (pour le test, on écrivait toujours au
--   début du buffer, on n'avait pas de FIFO)
-- 24-10-2012 augmenté le compte d'échantillons à stocker en MEB (il en manquait 1)
-- 25-10-2012 modifié l'adresse de l'énergie CsI rapide (1540 --> 1550)
-- 26-10-2012/0 ajouté pulldown sur glt et avec chiscope dans trigger
-- 26-10-2012/1 avec chiscope dans read_engine
-- 29-10-2012/0 modifié chipscope read_engine (ajouté bus hostIn et poussé tsRequest à la fin)
--              fonctionne avec le projet read_engine.cpj (modifié)
-- 29-10-2012/1 ajouté chipscope dans FastLink. il a été ajouté également la diffusion du pattern de test
--               x"8080" dans le cas où align=1 alors que reset=0
-- 30-10-2012/0 chispcope sur telescope
-- 5-11-2012/0 correction bugs sur lecture event number dans readEngine
-- 6-11-2012/0 ajouté registre d'échantillonnage d'ADC
-- 7-11-2012/0 ajouté zône de communication FPGA-PIC (32 octets en 0x0220)
-- 9-11-2012/0 version sauvegardée avant modifications en profondeur du protocole de communication
-- 12-11-2012/0 readEngine entièrement revue de sorte que B soit maintenant esclave de A
-- 14-11-2012/0 implémenté la synchro des acquisitions entre a et b
-- 14-11-2012/2 implémenté reset soft par le pic
-- 26-11-2012/0 corrigé la numérotation des objets dans le protoccole (TELID et DETID)
--              durée de lt = 40 ns sur le connecteur (synchro clk 25 MHz)
-- 29-11-2012/0 retiré commande automatique du signal align au reset
-- 29-11-2012/1 mis à jour les identificateurs telId et detId selon nouvelle spec
-- 03-12-2012/0 nouveau module ReadEngine: encapsulation B dans A, suppression de zéro,
--              parité et longueur totale du message NON gérés
-- 06-12-2012/0 installé (et testé) la suppression de zéro. la readEngine fonctionne maintenant
--              avec ni A ni B, A seul, B seul, A et B. pour inhiber la suppression de zéro d'une voie,
--              il suffit de programmer un seuil lent (suffisamment) négatif.