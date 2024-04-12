
module pll48MHz_module (
    input clk27mhz,
    output clk48mhz,
    output clk_locked
);

Gowin_rPLL pll48mhz (
    .clkout(clk48mhz), 
    .clkin(clk27mhz), 
    .lock_o(clk_locked), 
    .reset(1'b0), 
    .reset_p(1'b0),
    .clkfb(1'b0), 
    .clkoutd_o(),
    .fdiv(6'b0), 
    .idiv(6'b0)
);
	defparam pll48mhz.DEVICE = "GW1NR-9";
	defparam pll48mhz.FCLKIN = "27";
	defparam pll48mhz.IDIV_SEL = 8;
	defparam pll48mhz.FBDIV_SEL = 15;
	defparam pll48mhz.ODIV_SEL = 16;
	defparam pll48mhz.DYN_FBDIV_SEL="false";
	defparam pll48mhz.DYN_IDIV_SEL="false";
	defparam pll48mhz.DYN_ODIV_SEL="false";
	defparam pll48mhz.DYN_SDIV_SEL=124;
	defparam pll48mhz.PSDA_SEL="0000";


endmodule