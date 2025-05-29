`timescale 1ns / 1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

//---------------------------------------------------
// Transaction class: carries inputs and expected output
//---------------------------------------------------
class transaction extends uvm_sequence_item;
  `uvm_object_utils(transaction)
  bit [31:0]  A;
  bit [31:0]  B;
  bit [31:0]  Result;
  function new(string name = "transaction ");
    super.new(name);
  endfunction

endclass

//---------------------------------------------------
// Sequence: generates corner-case + random FP inputs
//---------------------------------------------------
class generator extends uvm_sequence#(transaction);
  `uvm_object_utils(generator)
transaction t;
  
  function new(string name = "generator");
    super.new(name);
  endfunction

  virtual task body();
    for(int i=1; i<5;i++)begin 
      t=transaction::type_id::create("TRANS");
      start_item(t);
      //t.randomize();
        //t.A = 32'h40900000; // 4.5 in float
        //t.B = 32'h3dcccccd;
        //t.A = 32'h42340000; // 45.0
      //  t.B = 32'h40000000; // 2.0
     // t.randomize(A);
     // t.randomize(B);
      
        t.A = $urandom_range(32'h4016E6C0, 32'h409F1000);
        t.B = $urandom_range(32'h4016E6C0, 32'h409F1000);
   
      $display("-----------------------");
      `uvm_info("gen",$sformatf("seq---->Driver A:%h  B:%h Result:%h",t.A,t.B,t.Result),UVM_NONE);
      finish_item(t);
    end 
  endtask
endclass

//---------------------------------------------------
// Driver: drives inputs to DUT and captures output
//---------------------------------------------------
class driver extends uvm_driver#(transaction);
  `uvm_component_utils(driver)
  transaction t;

  virtual interface fp_if vif;

  function new(string name = "driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction
    
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    t = transaction::type_id::create("t");

   if(!uvm_config_db#(virtual fp_if)::get(this, "", "vif", vif))
     `uvm_error("DRV", "Virtual interface not set for driver");
    endfunction

  virtual task run_phase(uvm_phase phase);
    //transaction t;
    forever begin
      seq_item_port.get_next_item(t);

      vif.A <= t.A;
      vif.B <= t.B;
      @(posedge vif.clk);
      @(posedge vif.clk);
      
      @(posedge vif.clk);
      @(posedge vif.clk);
      @(posedge vif.clk);
     
     
    // Delay to get output


      t.Result = vif.Result;

      `uvm_info("DRV", $sformatf("Driven A=%h, B=%h, Result=%h", 
                                 t.A,t.B,t.Result), UVM_NONE);

      seq_item_port.item_done();
    end
  endtask
endclass

//---------------------------------------------------
// Monitor: observes transactions
//---------------------------------------------------
class monitor extends uvm_monitor;
  `uvm_component_utils(monitor)

  virtual interface fp_if vif;
  uvm_analysis_port#(transaction) ap;

  function new(string name = "monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual fp_if)::get(this, "", "vif", vif))
      `uvm_error("MON", "Virtual interface not set for monitor")
  endfunction

  virtual task run_phase(uvm_phase phase);
    transaction t;
    forever begin
      @(posedge vif.clk);
      t = transaction::type_id::create("t");
      t.A = vif.A;
      t.B = vif.B;
      t.Result = vif.Result;

      `uvm_info("MON", $sformatf("DUT----->>Monitored: A=%h B=%h Result=%h", 
        t.A,t.B,t.Result), UVM_NONE);

      ap.write(t);
    end
  endtask
endclass

//---------------------------------------------------
// Scoreboard: compares DUT output with expected result
//---------------------------------------------------
class scoreboard extends uvm_scoreboard;
  `uvm_component_utils(scoreboard)

  // Analysis port to receive transactions from monitor
  uvm_analysis_imp#(transaction, scoreboard) ap;

  function new(string name = "scoreboard", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  // Write method gets called when monitor sends data
  function void write(transaction t);
    bit [31:0] expected_result;
    expected_result = golden_model(t.A, t.B);

    if (t.Result === expected_result) begin
      `uvm_info("SCOREBOARD", $sformatf("PASS: A=%h, B=%h, DUT Result=%h, Expected=%h",
                    t.A, t.B, t.Result, expected_result), UVM_MEDIUM)
    end else begin
      `uvm_error("SCOREBOARD", $sformatf("FAIL: A=%h, B=%h, DUT Result=%h, Expected=%h",
                    t.A, t.B, t.Result, expected_result))
    end
  endfunction

  // Golden reference: float multiply using SystemVerilog real math
  function bit [31:0] golden_model(bit [31:0] a, b);
  shortreal ra, rb, rresult;
  bit [31:0] result;

  ra = $bitstoshortreal(a);
  rb = $bitstoshortreal(b);
  rresult = ra * rb;
  result = $shortrealtobits(rresult);

  return result;
endfunction

endclass


//---------------------------------------------------
// Agent
//---------------------------------------------------
class agent extends uvm_agent;
  `uvm_component_utils(agent)

  virtual interface fp_if vif;
  driver drv;
  monitor mon;
  uvm_sequencer#(transaction) seqr;

  function new(string name = "agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this);
    drv  = driver::type_id::create("drv", this);
    mon  = monitor::type_id::create("mon", this);
    if (!uvm_config_db#(virtual fp_if)::get(this, "", "vif", vif))
      `uvm_fatal("AGENT", "Virtual interface not set for agent")
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
    drv.vif = vif;
    mon.vif = vif;
  endfunction
endclass

//---------------------------------------------------
// Environment
//---------------------------------------------------
class env extends uvm_env;
  `uvm_component_utils(env)

  agent ag;
  scoreboard sb;
  virtual interface fp_if vif;

  function new(string name = "env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ag = agent::type_id::create("ag", this);
    sb = scoreboard::type_id::create("sb", this);
    if (!uvm_config_db#(virtual fp_if)::get(this, "", "vif", vif))
      `uvm_fatal("ENV", "Virtual interface not set for env")
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    ag.mon.ap.connect(sb.ap);
    ag.vif = vif;
  endfunction
endclass

//---------------------------------------------------
// Test
//---------------------------------------------------
class test extends uvm_test;
  `uvm_component_utils(test)

  env e;
  generator gen;

  function new(string name = "test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    e = env::type_id::create("e", this);
    gen = generator::type_id::create("gen", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    gen.start(e.ag.seqr);
    #200;
    phase.drop_objection(this);
  endtask
endclass



//---------------------------------------------------
// DUT Instantiation and Top-level Testbench
//---------------------------------------------------
module tb_top;
  fp_if fp_if();

  // DUT should be defined elsewhere and included here
  fp_multiply dut (
    .clk(fp_if.clk),
    .reset(fp_if.reset),
    .A(fp_if.A),
    .B(fp_if.B),
    .Result(fp_if.Result)
  );

  initial fp_if.clk = 0;
  always #100 fp_if.clk = ~fp_if.clk;

  initial begin
    fp_if.reset = 1;
    #10;
    fp_if.reset = 0;
  end

  initial begin
    uvm_config_db#(virtual fp_if)::set(null, "*", "vif", fp_if);
    run_test("test");
  end
endmodule
