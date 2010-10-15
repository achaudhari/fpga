module fifo_to_wb_tb();
   
   reg clk = 0;
   reg rst = 1;
   reg clear = 0;
   initial #1000 rst = 0;
   always #50 clk = ~clk;
   
   reg 	       trigger = 0;
   initial #10000 trigger = 1;

   wire        wb_cyc, wb_stb, wb_we, wb_ack;
   wire [15:0] wb_adr;
   wire [15:0] wb_dat_miso, wb_dat_mosi;

   reg 	       cmd_src_rdy;
   wire        cmd_dst_rdy, resp_src_rdy, resp_dst_rdy;
   reg [17:0]  cmd;
   wire [17:0] resp;
   
   fifo_to_wb fifo_to_wb
     (.clk(clk), .reset(rst), .clear(clear),
      .data_i(cmd), .src_rdy_i(cmd_src_rdy), .dst_rdy_o(cmd_dst_rdy),
      .data_o(resp), .src_rdy_o(resp_src_rdy), .dst_rdy_i(resp_dst_rdy),

      .wb_adr_o(wb_adr), .wb_dat_mosi(wb_dat_mosi), .wb_dat_miso(wb_dat_miso),
      .wb_sel_o(), .wb_cyc_o(wb_cyc), .wb_stb_o(wb_stb), 
      .wb_we_o(wb_we), .wb_ack_i(wb_ack),
      .triggers());

   assign wb_dat_miso = {wb_adr[7:0],8'hBF};
   
   // Set up monitors
   always @(posedge clk)
     if(wb_cyc & wb_stb & wb_ack)
       if(wb_we)
	 $display("WB-WRITE  ADDR:%h  DATA:%h",wb_adr, wb_dat_mosi);
       else
	 $display("WB-READ  ADDR:%h  DATA:%h",wb_adr, wb_dat_miso);
   
   always @(posedge clk)
     if(cmd_src_rdy & cmd_dst_rdy)
       $display("CMD-WRITE  SOF:%b EOF:%b DATA:%h",cmd[16],cmd[17],cmd[15:0]);
   
   always @(posedge clk)
     if(resp_src_rdy & resp_dst_rdy)
       $display("RESP-READ  SOF:%b EOF:%b DATA:%h",resp[16],resp[17],resp[15:0]);

   assign wb_ack = wb_stb;
   assign resp_dst_rdy = 1;
   
   task InsertRW;
      input [15:0] data_start;
      input [5:0]  triggers;
      input [7:0]  seqno;
      input [15:0] len;
      input [15:0] addr;
      reg [15:0]   data_val;
      
      begin
	 data_val <= data_start;
	 @(posedge clk);
	 cmd <= {2'b01,2'b11,triggers,seqno};
	 cmd_src_rdy <= 1;
	 @(posedge clk);
	 cmd <= {2'b00,len};
	 @(posedge clk);
	 cmd <= {2'b00,addr};
	 @(posedge clk);
	 cmd <= {2'b00,16'd0};
	 @(posedge clk);
	 repeat (len)
	   begin
	      cmd <= {2'b00,data_val};
	      data_val <= data_val + 1;
	      @(posedge clk);
	   end
	 repeat (12-len-1)
	   begin
	      cmd <= {2'b00,16'hBEEF};
	      @(posedge clk);
	   end
	 cmd <= {2'b10, 16'hDEAD};
	 @(posedge clk);
	 cmd_src_rdy <= 0;
      end
   endtask // InsertRead
      
   initial $dumpfile("fifo_to_wb_tb.vcd");
   initial $dumpvars(0,fifo_to_wb_tb);

   initial
     begin
	@(negedge rst);
	//#10000;
	@(posedge clk);
	@(posedge clk);
	@(posedge clk);
	@(posedge clk);
	InsertRW(16'hF00D, 6'd0, 8'hB5, 16'd7, 16'h1234);
     end
   
   initial #20000 $finish;
endmodule // fifo_to_wb_tb
