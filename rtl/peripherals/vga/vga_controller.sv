module vga_controller (
    input  logic        clk_50_i,   // Reloj del sistema, 50 MHz
    input  logic        clk_25_i,   // Reloj de píxel, 25 MHz
    input  logic        rst_i,      // Reset general, activo en bajo

    // --- Interfaz con el bus del CPU ---
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        we_i,
    input  logic        cs_vga_i,

    output logic [31:0] rdata_o,

    // --- Salidas hacia el conector VGA físico ---
    output logic        hsync_o,
    output logic        vsync_o,
    output logic [3:0]  r_o,
    output logic [3:0]  g_o,
    output logic [3:0]  b_o
);

    localparam CTRL_ADDR  = 32'h0001_0120;
    localparam BUF_BASE   = 32'h0001_1000;
    localparam BUF_END    = 32'h0001_2DFF;

    // ------------------------------------------------------------------
    // REGISTRO DE CONTROL / CURSOR
    // ------------------------------------------------------------------
    logic [31:0] ctrl_reg;

    logic [6:0] cursor_col;
    logic [4:0] cursor_row;
    logic       blink_en;

    assign cursor_col = ctrl_reg[6:0];
    assign cursor_row = ctrl_reg[12:8];
    assign blink_en   = ctrl_reg[16];

    // ------------------------------------------------------------------
    // SEÑALES INTERNAS DEL VGA
    // Se declaran aquí antes de usarlas en cualquier always_comb.
    // ------------------------------------------------------------------
    logic [9:0]  hcount;
    logic [9:0]  vcount;
    logic        video_on;

    logic [7:0]  char_code;
    logic [3:0]  fg_color;
    logic [3:0]  bg_color;
    logic [31:0] vga_buf_rdata;

    // ------------------------------------------------------------------
    // ESCRITURA AL REGISTRO DE CONTROL
    // ------------------------------------------------------------------
    always_ff @(posedge clk_50_i or negedge rst_i) begin
        if (!rst_i)
            ctrl_reg <= 32'd0;
        else if (cs_vga_i && we_i && addr_i == CTRL_ADDR)
            ctrl_reg <= wdata_i;
    end

    // ------------------------------------------------------------------
    // LECTURA DESDE CPU
    // ------------------------------------------------------------------
    always_comb begin
        if (cs_vga_i && !we_i && addr_i == CTRL_ADDR)
            rdata_o = ctrl_reg;
        else if (cs_vga_i && !we_i && addr_i >= BUF_BASE && addr_i <= BUF_END)
            rdata_o = vga_buf_rdata;
        else
            rdata_o = 32'd0;
    end

    // --------------------------------------------------------------
    // INSTANCIA 1: generador de sincronismo VGA
    // --------------------------------------------------------------
    vga_timing_gen u_timing (
        .clk_25_i  (clk_25_i),
        .rst_i     (rst_i),
        .hsync_o   (hsync_o),
        .vsync_o   (vsync_o),
        .hcount_o  (hcount),
        .vcount_o  (vcount),
        .video_on_o(video_on)
    );

    // ------------------------------------------------------------------
    // INTERFAZ DE ESCRITURA HACIA EL BUFFER DE TEXTO
    // ------------------------------------------------------------------
    logic buf_we;

    assign buf_we = cs_vga_i && we_i &&
                    (addr_i >= BUF_BASE) && (addr_i <= BUF_END);

    // --------------------------------------------------------------
    // INSTANCIA 2: memoria de texto 80x24
    // --------------------------------------------------------------
    text_buffer u_buf (
        .clk_i      (clk_50_i),
        .we_i       (buf_we),
        .addr_i     (addr_i),
        .data_i     (wdata_i),

        .clk_25_i   (clk_25_i),
        .hcount_i   (hcount),
        .vcount_i   (vcount),

        .char_code_o(char_code),
        .fg_color_o (fg_color),
        .bg_color_o (bg_color),

        .cpu_rdata_o(vga_buf_rdata)
    );

    // ------------------------------------------------------------------
    // ROM DE FUENTES
    // ------------------------------------------------------------------
    logic [3:0] glyph_row;
    logic [7:0] pixel_row_data;
    logic       pixel_bit;

    assign glyph_row = vcount[3:0];

    font_rom u_font (
        .char_code_i(char_code),
        .row_i      (glyph_row),
        .pixel_row_o(pixel_row_data)
    );

    assign pixel_bit = pixel_row_data[3'd7 - hcount[2:0]];

    // ------------------------------------------------------------------
    // CURSOR PARPADEANTE
    // ------------------------------------------------------------------
    logic [24:0] blink_cnt;
    logic        blink_phase;

    always_ff @(posedge clk_25_i or negedge rst_i) begin
        if (!rst_i)
            blink_cnt <= '0;
        else
            blink_cnt <= blink_cnt + 1'b1;
    end

    assign blink_phase = blink_cnt[24];

    logic [6:0] cur_col_render;
    logic [4:0] cur_row_render;

    assign cur_col_render = hcount[9:3];
    assign cur_row_render = vcount[8:4];

    logic cursor_on;

    assign cursor_on = blink_en && blink_phase &&
                       (cur_col_render == cursor_col) &&
                       (cur_row_render == cursor_row);

    // --------------------------------------------------------------
    // INSTANCIA 4: paleta CGA
    // --------------------------------------------------------------
    cga_palette u_palette (
        .fg_color_i (fg_color),
        .bg_color_i (bg_color),
        .pixel_bit_i(pixel_bit),
        .video_on_i (video_on),
        .cursor_on_i(cursor_on),
        .r_o        (r_o),
        .g_o        (g_o),
        .b_o        (b_o)
    );

endmodule