-------------------------------------------------------------------------------
-- Copyright (c) 2012 Xilinx, Inc.
-- All Rights Reserved
-------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /    Vendor     : Xilinx
-- \   \   \/     Version    : 1.0
--  \   \         Application: Xilinx CORE Generator
--  /   /         Filename   : tel_icon.vho
-- /___/   /\     Timestamp  : mer. mars 14 10:39:13 CET 2012
-- \   \  /  \
--  \___\/\___\
--
-- Design Name: ISE Instantiation template
-------------------------------------------------------------------------------
-- The following code must appear in the VHDL architecture header:

------------- Begin Cut here for COMPONENT Declaration ------ COMP_TAG
component tel_icon
  PORT (
    CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));

end component;

-- Synplicity black box declaration
attribute syn_black_box : boolean;
attribute syn_black_box of tel_icon: component is true;

-- COMP_TAG_END ------ End COMPONENT Declaration ------------
-- The following code must appear in the VHDL architecture
-- body. Substitute your own instance name and net names.
------------- Begin Cut here for INSTANTIATION Template ----- INST_TAG

your_instance_name : tel_icon
  port map (
    CONTROL0 => CONTROL0);

-- INST_TAG_END ------ End INSTANTIATION Template ------------
