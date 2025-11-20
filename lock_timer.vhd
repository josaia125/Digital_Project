library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lock_timer is
    port (
        clk        : in  std_logic;                      -- 100 MHz clock
        reset      : in  std_logic;                      -- synchronous reset
        enable     : in  std_logic;                      -- iniciar bloqueo (nivel alto durante S_BLOQUEO)
        time_left  : out std_logic_vector(5 downto 0);   -- de 30 a 0
        finished   : out std_logic                       -- 1 cuando la cuenta llegó a 0 (lock terminado)
    );
end lock_timer;

architecture rtl of lock_timer is
    -- Prescaler 100 MHz -> 1 Hz (100_000_000 cycles)
    constant PRESCALE_MAX : unsigned(26 downto 0) := to_unsigned(100_000_000 - 1, 27);
    signal prescaler_cnt  : unsigned(26 downto 0) := (others => '0');
    signal sec_counter    : unsigned(5 downto 0) := (others => '0');
    signal running        : std_logic := '0';
    signal enable_prev    : std_logic := '0';
    signal finished_int   : std_logic := '0';

begin
    -- salidas
    time_left <= std_logic_vector(sec_counter);
    finished  <= finished_int;

    --------------------------------------------------------------------
    -- Prescaler + contador de segundos
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                prescaler_cnt <= (others => '0');
                sec_counter   <= (others => '0');
                running       <= '0';
                enable_prev   <= '0';
                finished_int  <= '0';
                
            else
                -- Detectar flanco positivo de enable
                enable_prev <= enable;
                
                -- Inicio: flanco 0->1 de enable
                if (enable = '1' and enable_prev = '0') then
                    sec_counter   <= to_unsigned(30, 6);  -- Cargar 30 segundos
                    running       <= '1';
                    prescaler_cnt <= (others => '0');
                    finished_int  <= '0';
                    
                elsif running = '1' then
                    -- Contador del prescaler
                    if prescaler_cnt = PRESCALE_MAX then
                        prescaler_cnt <= (others => '0');
                        
                        -- Decrementar cada segundo
                        if sec_counter > 0 then
                            sec_counter <= sec_counter - 1;
                            
                            -- Verificar si llegamos a 0
                            if sec_counter = 1 then  -- En el próximo ciclo será 0
                                running      <= '0';
                                finished_int <= '1';
                            end if;
                        end if;
                        
                    else
                        prescaler_cnt <= prescaler_cnt + 1;
                    end if;
                    
                else
                    -- No está corriendo: mantener todo en reposo
                    prescaler_cnt <= (others => '0');
                    
                    -- Mantener finished hasta nuevo enable o reset
                    if enable = '0' then
                        finished_int <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;

end rtl;
