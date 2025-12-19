module tdoa_stream #(
    parameter W = 64, // How many audio samples we compare at once
    parameter D = 22 // Max "lag" to check (depends on mic spacing (we had a max of 15cm difference))
)(
    input logic clk,
    input logic sample_valid, // high when new data arrives
    input logic signed [15:0] mic_A_in, // Audio from reference mic
    input logic signed [15:0] mic_B_in, // Audio from target mic

    output logic signed [5:0] delay_out, // How many samples Mic B is delayed vs A
    output logic result_ready
);

    // 4-bit compression
    // We only keep the sign bit + 3 data bits (limited resources on FPGA)
    // This reduces the cross-correlation computation complexity significantly
    logic signed [3:0] sample_A_4bit, sample_B_4bit;
    assign sample_A_4bit = mic_A_in[15:12];
    assign sample_B_4bit = mic_B_in[15:12];

    // Circular Buffers to store recent audio history
    // Each buffer holds W samples of 4-bit quantized audio data
    logic signed [3:0] buffer_A [0:W-1];
    logic signed [3:0] buffer_B [0:W-1];
    logic [$clog2(W)-1:0] wr_ptr; // Write pointer for circular buffers

    // State machine for TDOA computation
    // Implements cross-correlation algorithm in hardware
    typedef enum {IDLE, CAPTURE, RESET_LAG, MAC, CHECK_MAX, OUTPUT} state_t;
    state_t state = IDLE;

    // Computation variables
    integer k; // Loop counter for MAC operation
    logic signed [5:0] curr_d; // Current lag being tested (-D to +D)
    logic signed [15:0] accum; // Accumulator for cross-correlation sum
    logic signed [15:0] max_corr; // Maximum correlation found so far
    logic signed [5:0] best_d; // Best delay corresponding to max correlation

    // Safety limit for the MAC loop to prevent buffer overflow
    // LIMIT = W - 2D ensures we don't access beyond buffer bounds during correlation
    localparam LIMIT = W - 2*D;

    always_ff @(posedge clk) begin
        result_ready <= 0;

        case (state)
            // Initialize write pointer and transition to capture state
            IDLE: begin // Wait for start of new computation cycle
                wr_ptr <= 0;
                state <= CAPTURE;
            end

            // Wait for sample_valid to store each asmple pair
            CAPTURE: begin // Fill the circular buffers with W new audio samples
                if (sample_valid) begin
                    buffer_A[wr_ptr] <= sample_A_4bit;
                    buffer_B[wr_ptr] <= sample_B_4bit;
                    wr_ptr <= wr_ptr + 1;
                    if (wr_ptr == W-1) begin
                        state <= RESET_LAG;
                        curr_d <= -D;
                        max_corr <= -16'sd32000; // Initialize to minimum possible value
                    end
                end
            end

            // Reset accumulator and loop counter for MAC operation
            RESET_LAG: begin // Prepare for computing cross-correlation at current lag
                accum <= 0;
                k <= 0;
                state <= MAC;
            end

            // Compute sum of products: sum(buffer_A[k] * buffer_B[k + curr_d])
            // 4-bit muliplication saves FPGA resources
            MAC: begin // Multiply-Accumulate operation for cross-correlation
                if (k < LIMIT) begin
                    // Complex indexing ensures we stay within buffer bounds
                    // For negative lags, buffer_B is shifted left (earlier samples)
                    // For positive lags, buffer_B is shifted right (later samples)
                    accum <= accum + (buffer_A[k] * buffer_B[k + curr_d + D]);
                    k <= k + 1;
                end else begin
                    state <= CHECK_MAX;
                end
            end

            // Update best delay if current correlation is higher
            // Check if we've tested all lags from -D to +D
            CHECK_MAX: begin // Compare current correlation with maximum found so far
                if (accum > max_corr) begin
                    max_corr <= accum;
                    best_d <= curr_d;
                end

                if (curr_d == D) begin
                    state <= OUTPUT;
                end else begin
                    curr_d <= curr_d + 1;
                    state <= RESET_LAG;
                end
            end

            // Set result_ready high for one cycle to indicate valid output
            // Return to IDLE for next computation cycle
            OUTPUT: begin // Send computed delay results
                delay_out <= best_d;
                result_ready <= 1;
                state <= IDLE;
            end
        endcase
    end
endmodule