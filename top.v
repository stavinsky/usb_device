`include "usbcorev/usb.v"
`include "rpll.v"
// `include "uart_tx.v"
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

module top(
    input clk27mhz,
    inout usb_dp,
    inout usb_dn,
    input rst,
    output usb_dp_pull,
    output [4:0]ledrow,
    output clk_tst,
    output clk_tst1
);

wire clk48mhz;
wire clk_locked;

assign usb_dp_pull = rst;

pll48MHz_module usb_clk(
    .clk27mhz(clk27mhz),
    .clk48mhz(clk48mhz),
    .clk_locked(clk_locked)
);


initial begin
    
end
reg [4:0]r_ledrow = 5'b00000;
assign ledrow = ~r_ledrow;

reg [6:0] usb_address;
wire usb_rst; // set to 1 if usb device got reset from the host
reg[3:0] endpoint;  
reg transaction_active;
reg direction_in;
reg setup;
reg data_toggle;
reg [1:0] handshake;
reg [7:0] data_in;
reg [7:0] data_out;
reg data_in_valid;
reg data_strobe;
reg success; // crc is valid
reg usb_dp_sync;
reg usb_dn_sync;

always @(posedge clk48mhz) begin
    if (!usb_tx_en) begin
        usb_dp_sync <= 1'b1 ? usb_dp : 1'bz;
        usb_dn_sync <=  1'b1 ? usb_dn : 1'bz;;
    end

    
end

// reg uart_data_ready = 0;
// reg [7:0] uart_tx_tyte ;
// wire uart_tx_done;
// wire uart_busy;
// uart_tx  uart_tx_01(
//     .i_Clock(clk48mhz), 
//     .i_Tx_DV(uart_data_ready),
//     .i_Tx_Byte(uart_tx_tyte),
//     .o_Tx_Active(uart_busy),
//     .o_Tx_Serial(clk_tst1),
//     .o_Tx_Done(uart_tx_done)

// );

wire usb_tx_se0, usb_tx_j, usb_tx_en;
usb usb0(
    .rst_n(rst),
    .usb_address(usb_address),
    .usb_rst(usb_rst),
    .endpoint(endpoint),
    .transaction_active(transaction_active),
    .direction_in(direction_in),
    .setup(setup),
    .data_toggle(data_toggle),
    .handshake(handshake),
    .data_in(data_in),
    .data_in_valid(data_in_valid),
    .data_strobe(data_strobe),
    .success(success),
    .data_out(data_out),

    .clk_48(clk48mhz),
    .rx_j(usb_dp_sync),
    .rx_se0(!usb_dp_sync && !usb_dn_sync),

    .tx_se0(usb_tx_se0),
    .tx_j(usb_tx_j),
    .tx_en(usb_tx_en)
);



assign usb_dp = usb_tx_en? (usb_tx_se0? 1'b0: usb_tx_j): 1'bz;
assign usb_dn = usb_tx_en? (usb_tx_se0? 1'b0: !usb_tx_j): 1'bz;

reg [5:0] bytes_counter = 0;
reg [7:0] uart_counter = 0;
reg [6:0] bytes_out_counter = 0;
reg [7:0] bytes_in [0:63];
reg [7:0] bytes_out [0:63];
reg [6:0] bytes_out_number = 0;
wire start_trans_probe ;
assign clk_tst = success;
assign clk_tst1 = data_toggle;
localparam 
    st_idle = 0,
    st_setup_get_status = 1,
    st_data = 2,
    st_data_finish = 3,
    st_data_out = 4,
    st_data_out_finish = 5,
    st_start_transaction = 6,
    st_success_transaction = 7,
    st_do_nothing = 254;

reg [7:0] status = st_idle;
reg [5:0] expected_bytes = 0;

localparam
    hs_ack = 2'b00,
    hs_none = 2'b01,
    hs_nak = 2'b10,
    hs_stall = 2'b11;
reg data_strobe_loc = 0;
reg transaction_loc = 0;
reg [6:0] usb_addr_temp = 0;
always @(posedge clk48mhz ) begin
    data_strobe_loc <= data_strobe;
    transaction_loc <= transaction_active;

    case (status)
        st_idle: begin 
            if (transaction_active && !transaction_loc) begin
                // data_toggle <= 0;
                status <= st_start_transaction;
                if (!direction_in) begin 
                    bytes_counter <= 0;

                end
            end
        end
        st_start_transaction: begin
            if (usb_addr_temp >0 ) begin 
                usb_address <= usb_addr_temp;
                usb_addr_temp <= 0; 
            end 
            if (!direction_in) begin
                if (success) begin 
                    status <= st_success_transaction;
                end 
                if (data_strobe && !data_strobe_loc) begin 
                        
                        bytes_counter <= bytes_counter + 1 ;
                        bytes_in[bytes_counter] <= data_out;
                end
        
            end
            else begin
                if (bytes_counter <= expected_bytes) begin
                    if ( bytes_counter == 0 || (data_strobe && !data_strobe_loc)) begin
                        data_toggle <= 1'b1;
                        data_in_valid <= 1'b1;
                        data_in <= bytes_in[bytes_counter];
                        bytes_counter <= bytes_counter + 1;
                    end
                end else begin
                    status <= st_success_transaction;
                    data_in_valid <= 1'b0;
                    data_toggle <= 0;
                    
                end

            end

        end
        st_success_transaction: begin
            data_toggle <= 0;
            if (setup && bytes_counter > 0 && bytes_in[1] == 8'h05) begin // set status
                r_ledrow[1] <= 1; 
                data_toggle <= 1;
                usb_addr_temp <= bytes_in[2][6:0];
            end
            
            if (setup && bytes_counter > 0 && bytes_in[1] == 8'h06) begin // get descriptor
                
                // start_trans_probe <= 1;
                r_ledrow[0] <= 1;
                bytes_counter <= 0; 
                expected_bytes <= 20;
                // bytes_in[0:17] <= {8'h12, 8'h01, 8'h02, 8'h00, 8'hff, 8'hff, 8'hff, 8'h40, 8'h05, 8'h06, 8'h07, 8'h08, 8'h02, 8'h00, 8'h01, 8'h02, 8'h03, 8'h01}; 
                bytes_in[0] <= 8'h12; 
                bytes_in[1] <= 8'h01; 
                bytes_in[2] <= 8'h02; 
                bytes_in[3] <= 8'h00; 
                bytes_in[4] <= 8'hff; 
                bytes_in[5] <= 8'hff; 
                bytes_in[6] <= 8'hff; 
                bytes_in[7] <= 8'h40; 
                bytes_in[8] <= 8'h05;
                bytes_in[9] <= 8'h06;
                bytes_in[10] <= 8'h07; 
                bytes_in[11] <= 8'h08; 
                bytes_in[12] <= 8'h02; 
                bytes_in[13] <= 8'h00; 
                bytes_in[14] <= 8'h01; 
                bytes_in[15] <= 8'h02; 
                bytes_in[16] <= 8'h03;
                bytes_in[17] <= 8'h01;
                // data_toggle <= 1; 
                

            end 

            status <= st_idle;
        end
            
        default: begin
            status <= st_idle;

        end
        
    endcase
        
    if (!rst || usb_rst) begin
        // r_ledrow <= 5'b0; 
        r_ledrow <= 5'b00000; 
        uart_counter <= 0;
        bytes_out_counter <= 0;
        status <= st_idle;
        usb_address <= 0; 
        handshake <= hs_ack; 
        data_toggle <= 0;
        // start_trans_probe = 0;

    end

    
end

endmodule