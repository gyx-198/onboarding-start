`default_nettype none

module spi_peripheral (
  input nCS,
  input COPI,
  input SCLK,
  input clk,
  input rst_n, // low to reset
  output [15:0] en_out,
  output [15:0] en_pwm_mode,
  output [7:0] pwm_duty_cycle
);

// spi mode 0, data is sampled on rising SCLK and shifted out on falling SCLK, clock idle state is 0
reg sclk1 = 0, sclk_sync = 0, sclk_sync_2 = 0;
reg copi1 = 0, copi_sync = 0;
reg ncs1 = 0, ncs_sync = 0, ncs_sync_2 = 0;
reg ncs_p_edge;
reg sclk_p_edge;

reg [3:0] index = 4'hF;
reg [15:0] packet = 0;

reg transaction_ready = 0;
reg transaction_complete = 0;

// CDC
always@(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    sclk1 <= 0;    
    copi1 <= 0;    
    ncs1 <= 0;
  end else begin
    sclk1 <= SCLK;
    sclk_sync <= sclk1;
    sclk_sync_2 <= sclk_sync;
    sclk_p_edge <= (sclk_sync > sclk_sync_2) ? 1'b1 : 1'b0;

    copi1 <= COPI;
    copi_sync <= copi1;
        
    ncs1 <= nCS;
    ncs_sync <= ncs1;
    ncs_sync_2 <= ncs_sync;
    ncs_p_edge <= (ncs_sync > ncs_sync_2) ? 1'b1 : 1'b0;
  end
end

always@(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    transaction_ready <= 0;
  end else if (ncs_sync == 0 && sclk_p_edge) begin
    packet[index] <= copi_sync;
    index <= (index > 0) ? (index - 1) : 4'hF;
  end else if (ncs_p_edge) transaction_ready <= 1'b1;
  else if (transaction_complete) transaction_ready <= 0;
end

always@(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    transaction_complete <= 0;
  end else if (transaction_ready && !transaction_complete) begin
    casez(packet[15:8])
      en_out <= 0; en_pwm_mode <= 0; pwm_duty_cycle <= 0;
      8'h80: en_out[7:0] <= packet[7:0];
      8'h81: en_out[15:8] <= packet[7:0];
      8'h82: en_pwm_mode[7:0] <= packet[7:0];
      8'h83: en_pwm_mode[15:8] <= packet[7:0];
      8'h84: pwm_duty_cycle <= packet[7:0];
    endcase
    transaction_complete <= 1;
  end else if (!transaction_ready && transaction_complete) transaction_complete <= 0;

end

endmodule