module compass_solver (
    input logic clk,
    input logic trigger, // High when TDOA is ready
    input logic signed [5:0] dAB,
    input logic signed [5:0] dAC,

    output logic [7:0] leds // 8 LEDs: N, NE, E, SE, S, SW, W, NW
);

    // Check 8 compass directions (0-7) and maintain scores for each
    logic [2:0] check_idx; // loops 0 thorugh 7 - current direction being evaluated
    logic [7:0] scores [0:7]; // Running scores for each direction

    // Expected Delay Values for Each Direction
    // These values were pre-computed based on microphone geometry and sound speed
    logic signed [5:0] exp_AB;
    logic signed [5:0] exp_AC;

    always_comb begin
        case(check_idx)
            3'd0: begin exp_AB = -3; exp_AC = 3; end // N 
            3'd1: begin exp_AB = 6; exp_AC = 16; end // NE
            3'd2: begin exp_AB = 12; exp_AC = 19; end // E 
            3'd3: begin exp_AB = 12; exp_AC = 11; end // SE
            3'd4: begin exp_AB = 6; exp_AC = -2; end // S 
            3'd5: begin exp_AB = -5; exp_AC = -15; end // SW
            3'd6: begin exp_AB = -12; exp_AC = -19; end // W 
            3'd7: begin exp_AB = -11; exp_AC = -12; end // NW
            default: begin exp_AB = 0; exp_AC = 0; end
        endcase
    end

    // State Machine for Direction Evaluation
    typedef enum {IDLE, UPDATE, FIND_MAX} state_t;
    state_t state = IDLE;

    // Error Calculation and Score Updates
    logic [7:0] abs_diff_AB;
    logic [7:0] abs_diff_AC;
    logic [7:0] total_err;
    logic [7:0] old_val;
    logic [7:0] decayed;
    logic [7:0] bonus;
    logic [7:0] new_score;
    logic [7:0] max_score;
    logic [2:0] best_idx;


    // Updating scores with decay and bonus
    // Calculate error between measured and expected delays
    always_comb begin
        // Compute absolute differences between measured and expected delays (no abs function this time)
        abs_diff_AB = (dAB > exp_AB) ? (dAB - exp_AB) : (exp_AB - dAB);
        abs_diff_AC = (dAC > exp_AC) ? (dAC - exp_AC) : (exp_AC - dAC);
        total_err = abs_diff_AB + abs_diff_AC;

        // Score Update Calculation
        // - Apply exponential decay to old score (divide by 8)
        // - Add bonus for low error measurements
        // - Cap score at 255 to prevent overflow
        old_val = scores[check_idx];
        decayed = old_val - (old_val >> 3); // Fast decay (divide by 8)

        // Higher bonus for lower error (amplify importance of this)
        bonus = (total_err < 8) ? (8 - total_err) * 8 : 0;

        if (total_err < 8) begin
            if ((decayed + bonus) > 255) new_score = 255;
            else new_score = decayed + bonus;
        end else begin
            new_score = decayed; // No bonus for high error
        end
    end


    // State Machine
    always_ff @(posedge clk) begin
        case(state)
            IDLE: begin // Wait for new TDOA measurements
                if (trigger) begin
                    check_idx <= 0;
                    state <= UPDATE;
                end
            end

            // Calculate new score for current direction and move to next
            UPDATE: begin // Updates scores for all 8 directions
                // Use the score calculation from combinational logic above
                scores[check_idx] <= new_score;

                if (check_idx == 7) begin
                    check_idx <= 0;
                    max_score <= 0;
                    state <= FIND_MAX;
                end else begin
                    check_idx <= check_idx + 1;
                end
            end

            // Only accept directions with score > 40 (noise threshold)
            FIND_MAX: begin // Finds the direction with the highest score
                if (scores[check_idx] > max_score) begin
                    max_score <= scores[check_idx];
                    best_idx <= check_idx;
                end

                if (check_idx == 7) begin
                    // Evaluation complete - output result if score above threshold
                    if (max_score > 40) begin
                        leds <= (1 << best_idx); // Set LED for best direction
                    end else begin
                        leds <= 0; // No clear direction detected
                    end
                    state <= IDLE;
                end else begin
                    check_idx <= check_idx + 1;
                end
            end
        endcase
    end
endmodule