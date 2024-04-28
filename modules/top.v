module top(
        input clk27mhz,
        inout usb_dp,
        inout usb_dn,
        input rst_bttn,
        output usb_dp_pull,
        output uart // debug uart tx
    );


    wire clk48mhz;
    wire clk_locked;
    wire rst;

    power_on_reset por1(.clk(clk48mhz), .rst_in(rst_bttn), .rst_out(rst));
    assign usb_dp_pull = rst;

    usb_pll usb_clk(.clk27mhz(clk27mhz), .clk48mhz(clk48mhz), .clk_locked(clk_locked));
    buffered_usb buff_usb1 (
                     .clk(clk48mhz),
                     .usb_dp(usb_dp),
                     .usb_dn(usb_dn),
                     .rst(rst),
                     .uart_tx(uart)
                 );

endmodule
