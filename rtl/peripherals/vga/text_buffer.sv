module text_buffer (
    // Puerto CPU: escritura del editor y lectura para :w
    input  logic        clk_i,
    input  logic        we_i,
    input  logic [31:0] addr_i,
    input  logic [31:0] data_i,

    // Puerto VGA: lectura para dibujar caracteres
    input  logic        clk_25_i,
    input  logic [9:0]  hcount_i,
    input  logic [9:0]  vcount_i,

    output logic [7:0]  char_code_o,
    output logic [3:0]  fg_color_o,
    output logic [3:0]  bg_color_o,

    // Readback hacia CPU.
    // Permite que el firmware haga lw sobre VGA_BUF durante :w.
    output logic [31:0] cpu_rdata_o
);

    localparam logic [31:0] BASE_ADDR     = 32'h0001_1000;
    localparam logic [31:0] END_ADDR_EXCL = 32'h0001_2E00; // 0x1000 + 1920*4

    // -------------------------------------------------------------------------
    // Dirección del CPU dentro del buffer VGA.
    // Cada celda ocupa 4 bytes.
    // -------------------------------------------------------------------------
    logic        cpu_access;
    logic [31:0] cpu_byte_offset;
    logic [10:0] cpu_cell;
    logic [10:0] cpu_addr;
    logic        cpu_we;

    assign cpu_access      = (addr_i >= BASE_ADDR) && (addr_i < END_ADDR_EXCL);
    assign cpu_byte_offset = addr_i - BASE_ADDR;
    assign cpu_cell        = cpu_byte_offset[12:2];
    assign cpu_addr        = cpu_access ? cpu_cell : 11'd0;
    assign cpu_we          = cpu_access && we_i;

    // -------------------------------------------------------------------------
    // Cálculo de celda VGA.
    // Cada carácter ocupa 8x16 píxeles.
    // col = hcount / 8
    // row = vcount / 16
    // cell = row*80 + col = row*64 + row*16 + col
    // -------------------------------------------------------------------------
    logic [6:0]  col_vga;
    logic [4:0]  row_vga;
    logic [10:0] row_x64;
    logic [10:0] row_x16;
    logic [10:0] col_ext;
    logic [10:0] cell_vga_calc;
    logic [10:0] vga_addr;
    logic        video_cell_valid;
    logic        video_cell_valid_q;

    assign col_vga = hcount_i[9:3];
    assign row_vga = vcount_i[8:4];

    assign row_x64 = {row_vga, 6'b000000};
    assign row_x16 = {2'b00, row_vga, 4'b0000};
    assign col_ext = {4'b0000, col_vga};

    assign cell_vga_calc   = row_x64 + row_x16 + col_ext;
    assign video_cell_valid = (col_vga < 7'd80) && (row_vga < 5'd24);
    assign vga_addr         = video_cell_valid ? cell_vga_calc : 11'd0;

    always_ff @(posedge clk_25_i) begin
        video_cell_valid_q <= video_cell_valid;
    end

`ifdef SIMULATION

    // -------------------------------------------------------------------------
    // Modelo simple para ModelSim.
    // Este bloque NO se sintetiza en Quartus porque Quartus no usa +define+SIMULATION.
    // -------------------------------------------------------------------------
    logic [31:0] mem [0:1919];
    logic [31:0] cpu_q_raw;
    logic [31:0] vga_q_raw;

    always_ff @(posedge clk_i) begin
        if (cpu_access) begin
            cpu_q_raw <= mem[cpu_addr];

            if (cpu_we) begin
                mem[cpu_addr] <= data_i;
            end
        end else begin
            cpu_q_raw <= 32'd0;
        end
    end

    always_ff @(posedge clk_25_i) begin
        if (video_cell_valid) begin
            vga_q_raw <= mem[vga_addr];
        end else begin
            vga_q_raw <= 32'd0;
        end
    end

    assign cpu_rdata_o = cpu_access ? cpu_q_raw : 32'd0;

    assign char_code_o = video_cell_valid_q ? vga_q_raw[7:0]   : 8'd0;
    assign fg_color_o  = video_cell_valid_q ? vga_q_raw[11:8]  : 4'd0;
    assign bg_color_o  = video_cell_valid_q ? vga_q_raw[15:12] : 4'd0;

`else

    // -------------------------------------------------------------------------
    // Implementación real para Quartus.
    //
    // Se instancia altsyncram directamente para evitar que Quartus convierta
    // el buffer VGA en miles de ALMs/LABs.
    //
    // Puerto A:
    //   - clk_i
    //   - CPU escribe caracteres al buffer
    //   - CPU lee caracteres durante :w
    //
    // Puerto B:
    //   - clk_25_i
    //   - VGA lee caracteres para dibujar pantalla
    // -------------------------------------------------------------------------
    wire [31:0] cpu_q_raw;
    wire [31:0] vga_q_raw;

    altsyncram vga_text_ram (
        .clock0    (clk_i),
        .clock1    (clk_25_i),

        .address_a (cpu_addr),
        .data_a    (data_i),
        .wren_a    (cpu_we),
        .q_a       (cpu_q_raw),

        .address_b (vga_addr),
        .data_b    (32'd0),
        .wren_b    (1'b0),
        .q_b       (vga_q_raw)
    );

    defparam
        vga_text_ram.operation_mode = "BIDIR_DUAL_PORT",
        vga_text_ram.width_a = 32,
        vga_text_ram.widthad_a = 11,
        vga_text_ram.numwords_a = 1920,
        vga_text_ram.width_b = 32,
        vga_text_ram.widthad_b = 11,
        vga_text_ram.numwords_b = 1920,
        vga_text_ram.lpm_type = "altsyncram",
        vga_text_ram.ram_block_type = "M10K",
        vga_text_ram.intended_device_family = "Cyclone V",
        vga_text_ram.outdata_reg_a = "UNREGISTERED",
        vga_text_ram.outdata_reg_b = "UNREGISTERED",
        vga_text_ram.address_reg_b = "CLOCK1",
        vga_text_ram.indata_reg_b = "CLOCK1",
        vga_text_ram.wrcontrol_wraddress_reg_b = "CLOCK1",
        vga_text_ram.clock_enable_input_a = "BYPASS",
        vga_text_ram.clock_enable_input_b = "BYPASS",
        vga_text_ram.clock_enable_output_a = "BYPASS",
        vga_text_ram.clock_enable_output_b = "BYPASS",
        vga_text_ram.power_up_uninitialized = "FALSE",
        vga_text_ram.read_during_write_mode_mixed_ports = "DONT_CARE";

    assign cpu_rdata_o = cpu_access ? cpu_q_raw : 32'd0;

    assign char_code_o = video_cell_valid_q ? vga_q_raw[7:0]   : 8'd0;
    assign fg_color_o  = video_cell_valid_q ? vga_q_raw[11:8]  : 4'd0;
    assign bg_color_o  = video_cell_valid_q ? vga_q_raw[15:12] : 4'd0;

`endif

endmodule