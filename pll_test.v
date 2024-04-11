`include "pll_defines.vh"
`include "rpll.v"

module top(
    input clk27mhz,
    output clk_tst,
    input rst,
);

wire clk60mhz;
// assign clk_tst = clk60mhz;
wire reset;
assign reset = ~rst;
assign clk_tst = clk60mhz;
wire clk_locked;
wire clkoutd_o;
wire [5:0]fdiv;
assign fdiv = 6'd0;
wire [5:0]idiv;
assign idiv = 6'd0;
wire GND;
assign GND = 1'b0;

Gowin_rPLL pll60mhz (
    .clkout(clk60mhz), 
    .clkin(clk27mhz), 
    .lock_o(clk_locked), 
    .reset(reset), 
    .reset_p(GND),
    .clkfb(GND), 
    .clkoutd_o(clkoutd_o),
     .fdiv(fdiv), 
     .idiv(idiv)
);
	defparam pll60mhz.DEVICE = `PLL_DEVICE;
	defparam pll60mhz.FCLKIN = `PLL_FCLKIN;
	defparam pll60mhz.FBDIV_SEL = `PLL_FBDIV_SEL;
	defparam pll60mhz.IDIV_SEL =  `PLL_IDIV_SEL;
	defparam pll60mhz.ODIV_SEL =  `PLL_ODIV_SEL;
	defparam pll60mhz.DYN_FBDIV_SEL="false";
	defparam pll60mhz.DYN_IDIV_SEL="false";
	defparam pll60mhz.DYN_ODIV_SEL="false";
	defparam pll60mhz.DYN_SDIV_SEL=124;
	defparam pll60mhz.PSDA_SEL="0000";

endmodule