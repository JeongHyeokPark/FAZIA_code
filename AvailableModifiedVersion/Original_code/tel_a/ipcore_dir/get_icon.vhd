-------------------------------------------------------------------------------
-- Copyright (c) 2014 Xilinx, Inc.
-- All Rights Reserved
-------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /    Vendor     : Xilinx
-- \   \   \/     Version    : 14.6
--  \   \         Application: XILINX CORE Generator
--  /   /         Filename   : get_icon.vhd
-- /___/   /\     Timestamp  : mer. juin 04 23:22:43 CEST 2014
-- \   \  /  \
--  \___\/\___\
--
-- Design Name: VHDL Synthesis Wrapper
-------------------------------------------------------------------------------
-- This wrapper is used to integrate with Project Navigator and PlanAhead

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
ENTITY get_icon IS
  port (
    CONTROL0: inout std_logic_vector(35 downto 0));
END get_icon;

ARCHITECTURE get_icon_a OF get_icon IS
BEGIN

END get_icon_a;
