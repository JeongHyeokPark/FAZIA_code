--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions

--===============================================================================================
-- fichier de configuration telescope - B -
--===============================================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;

package telescope_conf is

constant build_a : boolean := false;

constant YEAR :   integer := 2019;
constant MONTH:   integer := 09;
constant DAY:     integer := 19;
constant VARIANT: integer := 1;

-- tyyy_ymmm_mddd_ddvv

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
constant chip_reader      : boolean := false; -- instanciate chipscope in waver>reader
constant chip_csi         : boolean := false;

end telescope_conf;

-- les commentaires concernant les modifications communes aux deux télescopes figurent
-- exclusivement dans le fichier tel_conf_a.vhd

-- 21-09-2012/0 modifié leds de trigger: voir tel_a
-- 28-09-2012/0 ajouté la gestion des générateurs de synchro d'alimenattion
-- 1-10-2012/0 ajouté la synchro des alims HT + signal de visualisation sur iofpga_5 (=sync_1.0)
-- 2-10-2012/0 chipscope dans read_engine
-- 3-10-2012/2 dans waver, ajouté plancher de la limite inférieure de longueur de signal
--   (on ne peut pas mettre moins de 4)
-- 4-10-2012/0 corrigé bug de lecture de registre dans blockTrig
-- 5-10-2012/0 ajouté relecture source et mode de trigger
-- 9-10-2012/0 mis à jour paramétrage et valeurs par défaut
-- 10-10-2012/0 glt provient par défaut du connecteur, modifié leds par défaut (lt, val,
--                                                                               couleurs A et B)
-- 11-10-2012/0 modifié le paramétrage pour augmenter la taille du MEB lent à 8192
--              (pour pouvoir observer le bruit à basse fréquence des alimentations block)
-- 17-10-2012 retour à des MEB QH1,Q2,Q3 de 4k. Il n'y a pas de place actuellement dans l'espace
-- d'adressage pour 8k. Nouvelle version de micro_wire (modif mineure des signaux LE)
-- 26-10-2012/0 ajouté pulldown sur glt et avec chiscope dans trigger
-- 26-10-2012/1 avec chiscope dans read_engine
-- 5-11-2012/0 correction bugs sur lecture event number dans readEngine
-- 7-11-2012/0 ajouté zône de communication FPGA-PIC (32 octets en 0x0220)
-- 12-11-2012 voir (A)
-- 14-11-2012/0 implémenté la synchro des acquisitions entre a et b
-- 14-11-2012/2 implémenté reset soft par le pic

-- 14-12-2012/0 signaux de commande des leds mémorisés et recopiés dans registre de contrôle
--              de general IO (notamment pour visualiser lt et val sur labview)

