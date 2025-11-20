library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity game_module is
    Port ( 
        clk_main     : in  STD_LOGIC;
        rst_system   : in  STD_LOGIC;
        btn_validate : in  STD_LOGIC;
        switches     : in  STD_LOGIC_VECTOR(3 downto 0);
        leds_tries   : out STD_LOGIC_VECTOR(4 downto 0);
        anode_ctrl   : out STD_LOGIC_VECTOR(3 downto 0);
        cathode_seg  : out STD_LOGIC_VECTOR(6 downto 0)
    );
end game_module;

architecture rtl of game_module is

    constant TRIES_MAX       : integer := 5;
    constant BLOCK_DURATION  : integer := 15;
    constant FAIL_MSG_TIME   : integer := 3;
    
    type fsm_state is (ST_IDLE, ST_SHOW_INPUT, ST_FEEDBACK, ST_WIN, ST_SHOW_FAIL, ST_BLOCKED);
    type result_type is (RES_NONE, RES_GO_UP, RES_GO_DOWN, RES_MATCH);
    
    signal fsm_current    : fsm_state := ST_IDLE;
    signal result_compare : result_type := RES_NONE;
    signal secret_num     : unsigned(3 downto 0) := "0000";
    signal lfsr_reg       : unsigned(15 downto 0) := "1010110011100001";
    signal trigger_random : STD_LOGIC := '0';
    signal tries_remaining : integer range 0 to TRIES_MAX := TRIES_MAX;
    
    signal pulse_1hz       : STD_LOGIC := '0';
    signal pulse_1hz_old   : STD_LOGIC := '0';
    signal cnt_prescaler   : integer range 0 to 100000000 := 0;
    signal timer_block     : integer range 0 to BLOCK_DURATION := 0;
    signal timer_fail_msg  : integer range 0 to FAIL_MSG_TIME := 0;
    
    signal btn_pipe        : STD_LOGIC_VECTOR(2 downto 0) := "000";
    signal btn_clean       : STD_LOGIC := '0';
    signal btn_rising      : STD_LOGIC := '0';
    signal debounce_cnt    : integer range 0 to 1000000 := 0;
    
    signal disp_0, disp_1, disp_2, disp_3 : STD_LOGIC_VECTOR(3 downto 0);
    signal refresh_cnt     : unsigned(16 downto 0) := (others => '0');
    signal sel_display     : STD_LOGIC_VECTOR(1 downto 0);
    signal active_digit    : STD_LOGIC_VECTOR(3 downto 0);
    
    -- Señal para almacenar el último intento
    signal last_attempt    : unsigned(3 downto 0) := "0000";
    
    function decode_hex_seg(nibble : STD_LOGIC_VECTOR(3 downto 0)) return STD_LOGIC_VECTOR is
        variable segs : STD_LOGIC_VECTOR(6 downto 0);
    begin
        case nibble is
            when "0000" => segs := "1000000"; -- 0
            when "0001" => segs := "1111001"; -- 1
            when "0010" => segs := "0100100"; -- 2
            when "0011" => segs := "0110000"; -- 3
            when "0100" => segs := "0011001"; -- 4
            when "0101" => segs := "0010010"; -- 5
            when "0110" => segs := "0000010"; -- 6
            when "0111" => segs := "1111000"; -- 7
            when "1000" => segs := "0000000"; -- 8
            when "1001" => segs := "0010000"; -- 9
            when "1010" => segs := "0001000"; -- A
            when "1011" => segs := "0000011"; -- b
            when "1100" => segs := "1000110"; -- C
            when "1101" => segs := "0100001"; -- d
            when "1110" => segs := "0000110"; -- E
            when "1111" => segs := "0001110"; -- F
            when others => segs := "1111111";
        end case;
        return segs;
    end function;
    
    function decode_char_seg(letra : character) return STD_LOGIC_VECTOR is
        variable segs : STD_LOGIC_VECTOR(6 downto 0);
    begin
        case letra is
            when 'S' => segs := "0010010";
            when 'U' => segs := "1000001";
            when 'B' => segs := "0000011";
            when 'E' => segs := "0000110";
            when 'A' => segs := "0001000";
            when 'J' => segs := "1100001";
            when 'F' => segs := "0001110";
            when 'I' => segs := "1111001";
            when 'L' => segs := "1000111";
            when 'O' => segs := "1000000";
            when 'H' => segs := "0001001";
            when '-' => segs := "1111111";
            when others => segs := "1111111";
        end case;
        return segs;
    end function;

begin

    -- Generador 1Hz
    process(clk_main, rst_system)
    begin
        if rst_system = '1' then
            cnt_prescaler <= 0;
            pulse_1hz <= '0';
        elsif rising_edge(clk_main) then
            if cnt_prescaler = 50000000-1 then
                cnt_prescaler <= 0;
                pulse_1hz <= not pulse_1hz;
            else
                cnt_prescaler <= cnt_prescaler + 1;
            end if;
        end if;
    end process;
    
    -- LFSR
    process(clk_main, rst_system)
        variable xor_bit : STD_LOGIC;
    begin
        if rst_system = '1' then
            lfsr_reg <= "1010110011100001";
        elsif rising_edge(clk_main) then
            xor_bit := lfsr_reg(15) xor lfsr_reg(13) xor lfsr_reg(12) xor lfsr_reg(10);
            lfsr_reg <= lfsr_reg(14 downto 0) & xor_bit;
            
            if trigger_random = '1' then
                secret_num <= lfsr_reg(3 downto 0);
            end if;
        end if;
    end process;
    
    -- Anti-rebote
    process(clk_main, rst_system)
    begin
        if rst_system = '1' then
            btn_pipe <= "000";
            btn_clean <= '0';
            debounce_cnt <= 0;
        elsif rising_edge(clk_main) then
            btn_pipe <= btn_pipe(1 downto 0) & btn_validate;
            
            if btn_pipe(2) /= btn_clean then
                if debounce_cnt = 1000000-1 then
                    btn_clean <= btn_pipe(2);
                    debounce_cnt <= 0;
                else
                    debounce_cnt <= debounce_cnt + 1;
                end if;
            else
                debounce_cnt <= 0;
            end if;
        end if;
    end process;
    
    -- Detector de flanco
    process(clk_main, rst_system)
        variable btn_history : STD_LOGIC := '0';
    begin
        if rst_system = '1' then
            btn_rising <= '0';
            btn_history := '0';
        elsif rising_edge(clk_main) then
            btn_rising <= btn_clean and not btn_history;
            btn_history := btn_clean;
        end if;
    end process;
    
    -- FSM PRINCIPAL
    process(clk_main, rst_system)
        variable player_input : unsigned(3 downto 0);
        variable detect_edge  : STD_LOGIC;
    begin
        if rst_system = '1' then
            fsm_current <= ST_IDLE;
            tries_remaining <= TRIES_MAX;
            result_compare <= RES_NONE;
            trigger_random <= '1';
            timer_block <= 0;
            timer_fail_msg <= 0;
            pulse_1hz_old <= '0';
            last_attempt <= "0000";
            
        elsif rising_edge(clk_main) then
            trigger_random <= '0';
            detect_edge := pulse_1hz and not pulse_1hz_old;
            pulse_1hz_old <= pulse_1hz;
            
            case fsm_current is
                
                when ST_IDLE =>
                    tries_remaining <= TRIES_MAX;
                    result_compare <= RES_NONE;
                    timer_block <= 0;
                    timer_fail_msg <= 0;
                    last_attempt <= "0000";
                    
                    if btn_rising = '1' then
                        trigger_random <= '1';
                        fsm_current <= ST_SHOW_INPUT;
                    end if;
                
                -- NUEVO ESTADO: Mostrar entrada del usuario
                when ST_SHOW_INPUT =>
                    -- Usuario ingresa número con switches
                    -- Muestra el número en tiempo real
                    if btn_rising = '1' then
                        -- Capturar el intento
                        player_input := unsigned(switches);
                        last_attempt <= player_input;
                        
                        -- Comparar
                        if player_input = secret_num then
                            result_compare <= RES_MATCH;
                            fsm_current <= ST_WIN;
                        elsif player_input < secret_num then
                            result_compare <= RES_GO_UP;
                            tries_remaining <= tries_remaining - 1;
                            fsm_current <= ST_FEEDBACK;
                        else
                            result_compare <= RES_GO_DOWN;
                            tries_remaining <= tries_remaining - 1;
                            fsm_current <= ST_FEEDBACK;
                        end if;
                    end if;
                
                -- NUEVO ESTADO: Mostrar retroalimentación SUBE/BAJA
                when ST_FEEDBACK =>
                    -- Mostrar SUBE o BAJA
                    if btn_rising = '1' then
                        -- Verificar si quedan intentos
                        if tries_remaining = 0 then
                            fsm_current <= ST_SHOW_FAIL;
                            timer_fail_msg <= FAIL_MSG_TIME;
                        else
                            fsm_current <= ST_SHOW_INPUT;
                        end if;
                    end if;
                
                when ST_WIN =>
                    if btn_rising = '1' then
                        fsm_current <= ST_IDLE;
                    end if;
                
                when ST_SHOW_FAIL =>
                    if detect_edge = '1' then
                        if timer_fail_msg > 0 then
                            timer_fail_msg <= timer_fail_msg - 1;
                        end if;
                    end if;
                    
                    if timer_fail_msg = 0 then
                        fsm_current <= ST_BLOCKED;
                        timer_block <= BLOCK_DURATION;
                    end if;
                
                when ST_BLOCKED =>
                    if detect_edge = '1' then
                        if timer_block > 0 then
                            timer_block <= timer_block - 1;
                        end if;
                    end if;
                    
                    if timer_block = 0 then
                        fsm_current <= ST_IDLE;
                    end if;
                
                when others =>
                    fsm_current <= ST_IDLE;
            end case;
        end if;
    end process;
    
    -- Control LEDs
    process(fsm_current, tries_remaining, pulse_1hz)
    begin
        leds_tries <= "00000";
        
        case fsm_current is
            when ST_IDLE | ST_SHOW_INPUT | ST_FEEDBACK =>
                case tries_remaining is
                    when 5 => leds_tries <= "11111";
                    when 4 => leds_tries <= "01111";
                    when 3 => leds_tries <= "00111";
                    when 2 => leds_tries <= "00011";
                    when 1 => leds_tries <= "00001";
                    when 0 => leds_tries <= "00000";
                    when others => leds_tries <= "00000";
                end case;
            
            when ST_WIN =>
                leds_tries <= "11111";
            
            when ST_SHOW_FAIL =>
                if pulse_1hz = '1' then
                    leds_tries <= "11111";
                else
                    leds_tries <= "00000";
                end if;
            
            when ST_BLOCKED =>
                leds_tries <= "00000";
        end case;
    end process;
    
    -- Asignación displays
    process(fsm_current, result_compare, timer_block, switches, last_attempt)
        variable dec, uni : integer;
        variable num_hex : unsigned(3 downto 0);
    begin
        case fsm_current is
            when ST_IDLE =>
                disp_3 <= "1111";
                disp_2 <= "1111";
                disp_1 <= "1111";
                disp_0 <= "1111";
            
            when ST_SHOW_INPUT =>
                -- Mostrar número actual en hexadecimal
                num_hex := unsigned(switches);
                disp_3 <= "1111";
                disp_2 <= "1111";
                disp_1 <= "1111";
                disp_0 <= std_logic_vector(num_hex);
            
            when ST_FEEDBACK =>
                -- Mostrar SUBE o BAJA
                if result_compare = RES_GO_UP then
                    disp_3 <= "0001"; -- S
                    disp_2 <= "0010"; -- U
                    disp_1 <= "0011"; -- B
                    disp_0 <= "0100"; -- E
                elsif result_compare = RES_GO_DOWN then
                    disp_3 <= "0101"; -- B
                    disp_2 <= "0110"; -- A
                    disp_1 <= "0111"; -- J
                    disp_0 <= "0110"; -- A
                else
                    disp_3 <= "1111";
                    disp_2 <= "1111";
                    disp_1 <= "1111";
                    disp_0 <= "1111";
                end if;
            
            when ST_WIN =>
                disp_3 <= "1111";
                disp_2 <= "1111";
                disp_1 <= "0000"; -- O
                disp_0 <= "1000"; -- H
            
            when ST_SHOW_FAIL =>
                disp_3 <= "1001"; -- F
                disp_2 <= "1010"; -- A
                disp_1 <= "1011"; -- I
                disp_0 <= "1100"; -- L
            
            when ST_BLOCKED =>
                dec := timer_block / 10;
                uni := timer_block mod 10;
                disp_3 <= "1111";
                disp_2 <= "1111";
                disp_1 <= std_logic_vector(to_unsigned(dec, 4));
                disp_0 <= std_logic_vector(to_unsigned(uni, 4));
        end case;
    end process;
    
    -- Multiplexación
    process(clk_main, rst_system)
    begin
        if rst_system = '1' then
            refresh_cnt <= (others => '0');
        elsif rising_edge(clk_main) then
            refresh_cnt <= refresh_cnt + 1;
        end if;
    end process;
    
    sel_display <= std_logic_vector(refresh_cnt(16 downto 15));
    
    process(sel_display, disp_0, disp_1, disp_2, disp_3)
    begin
        case sel_display is
            when "00" =>
                anode_ctrl <= "1110";
                active_digit <= disp_0;
            when "01" =>
                anode_ctrl <= "1101";
                active_digit <= disp_1;
            when "10" =>
                anode_ctrl <= "1011";
                active_digit <= disp_2;
            when "11" =>
                anode_ctrl <= "0111";
                active_digit <= disp_3;
            when others =>
                anode_ctrl <= "1111";
                active_digit <= "0000";
        end case;
    end process;
    
    -- Decodificación 7 segmentos
    process(active_digit, fsm_current, disp_0, disp_1, disp_2, disp_3)
    begin
        case fsm_current is
            when ST_FEEDBACK =>
                case active_digit is
                    when "0001" => cathode_seg <= decode_char_seg('S');
                    when "0010" => cathode_seg <= decode_char_seg('U');
                    when "0011" => cathode_seg <= decode_char_seg('B');
                    when "0100" => cathode_seg <= decode_char_seg('E');
                    when "0101" => cathode_seg <= decode_char_seg('B');
                    when "0110" => cathode_seg <= decode_char_seg('A');
                    when "0111" => cathode_seg <= decode_char_seg('J');
                    when others => cathode_seg <= decode_hex_seg(active_digit);
                end case;
            
            when ST_WIN =>
                case active_digit is
                    when "0000" => cathode_seg <= decode_char_seg('O');
                    when "1000" => cathode_seg <= decode_char_seg('H');
                    when others => cathode_seg <= decode_char_seg('-');
                end case;
            
            when ST_SHOW_FAIL =>
                case active_digit is
                    when "1001" => cathode_seg <= decode_char_seg('F');
                    when "1010" => cathode_seg <= decode_char_seg('A');
                    when "1011" => cathode_seg <= decode_char_seg('I');
                    when "1100" => cathode_seg <= decode_char_seg('L');
                    when others => cathode_seg <= decode_char_seg('-');
                end case;
            
            when others =>
                cathode_seg <= decode_hex_seg(active_digit);
        end case;
    end process;

end rtl;