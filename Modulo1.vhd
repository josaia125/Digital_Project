library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_modulo1 is
    port (
        clk   : in  std_logic;   -- 100 MHz Basys3
        reset : in  std_logic;   -- BTNR

        btnL  : in  std_logic;   -- entrar configuración
        btnC  : in  std_logic;   -- guardar clave
        sw    : in  std_logic_vector(3 downto 0); -- ingreso clave

        an    : out std_logic_vector(3 downto 0); -- display
        seg   : out std_logic_vector(6 downto 0);

        access_granted : out std_logic            -- habilita módulo 2
    );
end top_modulo1;

architecture rtl of top_modulo1 is

    --------------------------------------------------------------------
    -- Declaración de estados FSM
    --------------------------------------------------------------------
    type state_type is (
        S_INICIO,
        S_CONFIG,
        S_GUARDADA,
        S_VERIF,
        S_ERROR,
        S_BLOQUEO,
        S_OK
    );
    signal state, next_state : state_type := S_INICIO;

    --------------------------------------------------------------------
    -- Señales internas
    --------------------------------------------------------------------
    signal stored_key    : std_logic_vector(3 downto 0);
    signal match_key     : std_logic;

    signal attempts      : std_logic_vector(1 downto 0);

    signal lock_time     : std_logic_vector(5 downto 0);
    signal lock_done     : std_logic;

    -- Señal "mode" para mostrar en display_ctrl
    signal mode_display  : std_logic_vector(3 downto 0);

    -- Botones "one-shot" por flanco positivo
    signal btnL_reg, btnL_prev : std_logic := '0';
    signal btnC_reg, btnC_prev : std_logic := '0';
    signal btnL_rise, btnC_rise : std_logic;

    --------------------------------------------------------------------
    -- Señales de control para los submódulos
    --------------------------------------------------------------------
    signal load_key  : std_logic := '0';
    signal fail_pulse : std_logic := '0';
    signal clear_attempts : std_logic := '0';
    signal enable_lock : std_logic := '0';

begin
    --------------------------------------------------------------------
    -- Flanco positivo para botones (one-shot)
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            btnL_prev <= btnL_reg;
            btnC_prev <= btnC_reg;

            btnL_reg <= btnL;
            btnC_reg <= btnC;
        end if;
    end process;

    btnL_rise <= '1' when (btnL_reg='1' and btnL_prev='0') else '0';
    btnC_rise <= '1' when (btnC_reg='1' and btnC_prev='0') else '0';

    --------------------------------------------------------------------
    -- Instancia: key_storage
    --------------------------------------------------------------------
    key_storage_inst : entity work.key_storage
        port map (
            clk        => clk,
            reset      => reset,
            load_key   => load_key,
            sw_key     => sw,
            stored_key => stored_key
        );

    --------------------------------------------------------------------
    -- Instancia: key_verify
    --------------------------------------------------------------------
    key_verify_inst : entity work.key_verify
        port map (
            entered_key => sw,
            stored_key  => stored_key,
            match       => match_key
        );

    --------------------------------------------------------------------
    -- Instancia: intent_counter
    --------------------------------------------------------------------
    intent_count_inst : entity work.intent_counter
        port map (
            clk   => clk,
            reset => reset,
            fail  => fail_pulse,
            clear => clear_attempts,
            count => attempts
        );

    --------------------------------------------------------------------
    -- Instancia: lock_timer
    --------------------------------------------------------------------
    lock_timer_inst : entity work.lock_timer
        port map (
            clk       => clk,
            reset     => reset,
            enable    => enable_lock,
            time_left => lock_time,
            finished  => lock_done
        );

    --------------------------------------------------------------------
    -- Instancia: display_ctrl
    --------------------------------------------------------------------
    display_inst : entity work.display_ctrl
        port map (
            clk     => clk,
            reset   => reset,
            mode    => mode_display,
            intento => attempts,
            timer   => lock_time,
            an      => an,
            seg     => seg
        );

    --------------------------------------------------------------------
    -- FSM secuencial
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= S_INICIO;
            else
                state <= next_state;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- FSM combinacional
    --------------------------------------------------------------------
    process(state, btnL_rise, btnC_rise, match_key, attempts, lock_done)
    begin
        -- Valores por defecto
        next_state      <= state;
        load_key        <= '0';
        fail_pulse      <= '0';
        clear_attempts  <= '0';
        enable_lock     <= '0';
        access_granted  <= '0';
        mode_display    <= "0000"; -- inicio por defecto

        case state is

            ----------------------------------------------------------------
            -- 1) Estado inicial
            ----------------------------------------------------------------
            when S_INICIO =>
                mode_display <= "0000";
                clear_attempts <= '1';
                if btnL_rise = '1' then
                    next_state <= S_CONFIG;
                end if;

            ----------------------------------------------------------------
            -- 2) Estado de configuración de clave
            ----------------------------------------------------------------
            when S_CONFIG =>
                mode_display <= "0001";
                if btnC_rise = '1' then
                    load_key   <= '1';
                    next_state <= S_GUARDADA;
                end if;

            ----------------------------------------------------------------
            -- 3) Clave guardada, pasar a verificación
            ----------------------------------------------------------------
            when S_GUARDADA =>
                 mode_display <= "0010"; -- mostrar 2 (clave guardada)
                 -- esperar a que usuario pulse botón para pasar
                 if btnC_rise = '1' then
                     next_state <= S_VERIF;
                 end if;

            ----------------------------------------------------------------
            -- 4) Verificación de la clave
            ----------------------------------------------------------------
            when S_VERIF =>
                mode_display <= "0011"; -- muestra "3"
                if btnC_rise = '1' then
                    if match_key = '1' then
                        next_state <= S_OK;
                    else
                        fail_pulse <= '1';
                        next_state <= S_ERROR;
                    end if;
                end if;

            ----------------------------------------------------------------
            -- 5) Error: restan intentos
            ----------------------------------------------------------------
            when S_ERROR =>
                mode_display <= "1111"; -- display_ctrl mostrará # intentos
                if attempts = "00" then
                    next_state <= S_BLOQUEO;
                else
                    next_state <= S_VERIF;
                end if;

            ----------------------------------------------------------------
            -- 6) Bloqueo 30 s
            ----------------------------------------------------------------
            when S_BLOQUEO =>
                mode_display <= "0000"; -- display_ctrl ya muestra timer
                enable_lock <= '1';
                if lock_done = '1' then
                    next_state <= S_INICIO;
                end if;

            ----------------------------------------------------------------
            -- 7) Acceso correcto
            ----------------------------------------------------------------
            when S_OK =>
                mode_display <= "1010"; -- 'A'
                access_granted <= '1';
                -- el sistema queda en OK hasta que el usuario resetee
                -- para evitar entrar varias veces en el juego
                -- o usar BTNL para reconfigurar
            ----------------------------------------------------------------

        end case;
    end process;

end rtl;

