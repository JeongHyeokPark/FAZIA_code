// file: My_sysmon.v
// (c) Copyright 2009 - 2010 Xilinx, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
`timescale 1ns / 1 ps

(* X_CORE_INFO = "sysmon_wiz_v2_1, Coregen 12.4" *)


module My_sysmon
          (
          CONVST_IN,           // Convert Start Input
          DADDR_IN,            // Address bus for the dynamic reconfiguration port
          DCLK_IN,             // Clock input for the dynamic reconfiguration port
          DEN_IN,              // Enable Signal for the dynamic reconfiguration port
          DI_IN,               // Input data bus for the dynamic reconfiguration port
          DWE_IN,              // Write Enable for the dynamic reconfiguration port
          RESET_IN,            // Reset signal for the System Monitor control logic
          BUSY_OUT,            // ADC Busy signal
          CHANNEL_OUT,         // Channel Selection Outputs
          DO_OUT,              // Output data bus for dynamic reconfiguration port
          DRDY_OUT,            // Data ready signal for the dynamic reconfiguration port
          EOC_OUT,             // End of Conversion Signal
          EOS_OUT,             // End of Sequence Signal
          VP_IN,               // Dedicated Analog Input Pair
          VN_IN);

          input CONVST_IN;
          input [6:0] DADDR_IN;
          input DCLK_IN;
          input DEN_IN;
          input [15:0] DI_IN;
          input DWE_IN;
          input RESET_IN;
          input VP_IN;
          input VN_IN;

          output BUSY_OUT;
          output [4:0] CHANNEL_OUT;
          output [15:0] DO_OUT;
          output DRDY_OUT;
          output EOC_OUT;
          output EOS_OUT;
        wire FLOAT_VCCAUX;
        wire FLOAT_VCCINT;
        wire FLOAT_TEMP;
          wire GND_BIT;
    wire [2:0] GND_BUS3;
          assign GND_BIT = 0;
          wire [15:0] aux_channel_p;
          wire [15:0] aux_channel_n;

          assign aux_channel_p[0] = 1'b0;
          assign aux_channel_n[0] = 1'b0;

          assign aux_channel_p[1] = 1'b0;
          assign aux_channel_n[1] = 1'b0;

          assign aux_channel_p[2] = 1'b0;
          assign aux_channel_n[2] = 1'b0;

          assign aux_channel_p[3] = 1'b0;
          assign aux_channel_n[3] = 1'b0;

          assign aux_channel_p[4] = 1'b0;
          assign aux_channel_n[4] = 1'b0;

          assign aux_channel_p[5] = 1'b0;
          assign aux_channel_n[5] = 1'b0;

          assign aux_channel_p[6] = 1'b0;
          assign aux_channel_n[6] = 1'b0;

          assign aux_channel_p[7] = 1'b0;
          assign aux_channel_n[7] = 1'b0;

          assign aux_channel_p[8] = 1'b0;
          assign aux_channel_n[8] = 1'b0;

          assign aux_channel_p[9] = 1'b0;
          assign aux_channel_n[9] = 1'b0;

          assign aux_channel_p[10] = 1'b0;
          assign aux_channel_n[10] = 1'b0;

          assign aux_channel_p[11] = 1'b0;
          assign aux_channel_n[11] = 1'b0;

          assign aux_channel_p[12] = 1'b0;
          assign aux_channel_n[12] = 1'b0;

          assign aux_channel_p[13] = 1'b0;
          assign aux_channel_n[13] = 1'b0;

          assign aux_channel_p[14] = 1'b0;
          assign aux_channel_n[14] = 1'b0;

          assign aux_channel_p[15] = 1'b0;
          assign aux_channel_n[15] = 1'b0;

SYSMON #(
        .INIT_40(16'h0200), // config reg 0
        .INIT_41(16'h30ff), // config reg 1
        .INIT_42(16'h1400), // config reg 2
        .INIT_48(16'h0100), // Sequencer channel selection
        .INIT_49(16'h0000), // Sequencer channel selection
        .INIT_4A(16'h0000), // Sequencer Average selection
        .INIT_4B(16'h0000), // Sequencer Average selection
        .INIT_4C(16'h0000), // Sequencer Bipolar selection
        .INIT_4D(16'h0000), // Sequencer Bipolar selection
        .INIT_4E(16'h0000), // Sequencer Acq time selection
        .INIT_4F(16'h0000), // Sequencer Acq time selection
        .INIT_50(16'hb5ed), // Temp alarm trigger
        .INIT_51(16'h5999), // Vccint upper alarm limit
        .INIT_52(16'he000), // Vccaux upper alarm limit
        .INIT_54(16'ha93a), // Temp alarm reset
        .INIT_55(16'h5111), // Vccint lower alarm limit
        .INIT_56(16'hcaaa), // Vccaux lower alarm limit
        .INIT_57(16'hae4e),  // Temp alarm OT reset
        .SIM_MONITOR_FILE("design.txt")
)

SYSMON_INST (
        .CONVST(CONVST_IN),
        .CONVSTCLK(GND_BIT),
        .DADDR(DADDR_IN[6:0]),
        .DCLK(DCLK_IN),
        .DEN(DEN_IN),
        .DI(DI_IN[15:0]),
        .DWE(DWE_IN),
        .RESET(RESET_IN),
        .VAUXN(aux_channel_n[15:0]),
        .VAUXP(aux_channel_p[15:0]),
        .ALM({FLOAT_VCCAUX, FLOAT_VCCINT, FLOAT_TEMP}),
        .BUSY(BUSY_OUT),
        .CHANNEL(CHANNEL_OUT[4:0]),
        .DO(DO_OUT[15:0]),
        .DRDY(DRDY_OUT),
        .EOC(EOC_OUT),
        .EOS(EOS_OUT),
        .JTAGBUSY(),
        .JTAGLOCKED(),
        .JTAGMODIFIED(),
        .OT(),
        .VP(VP_IN),
        .VN(VN_IN)
          );

endmodule
